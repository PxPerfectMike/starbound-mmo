import type * as Party from 'partykit/server'

interface PlayerPresence {
  playerId: string
  displayName: string
  zone: string
  lastSeen: number
}

interface PresenceState {
  players: Map<string, PlayerPresence>
}

export default class PresenceServer implements Party.Server {
  private state: PresenceState = { players: new Map() }

  constructor(public room: Party.Room) {}

  onConnect(conn: Party.Connection, ctx: Party.ConnectionContext) {
    // Send current online players to new connection
    const onlinePlayers = Array.from(this.state.players.values()).map((p) => ({
      playerId: p.playerId,
      displayName: p.displayName,
      zone: p.zone,
      lastSeen: new Date(p.lastSeen).toISOString(),
    }))

    conn.send(
      JSON.stringify({
        type: 'presence_sync',
        onlinePlayers,
      })
    )
  }

  onClose(conn: Party.Connection) {
    // Try to find and remove the player by connection
    // Note: In a real implementation, we'd track connection -> playerId mapping
    const playerId = conn.id
    if (this.state.players.has(playerId)) {
      const player = this.state.players.get(playerId)!
      this.state.players.delete(playerId)
      this.broadcast({
        type: 'player_offline',
        playerId: player.playerId,
        displayName: player.displayName,
      })
    }
  }

  onMessage(message: string, sender: Party.Connection) {
    const data = JSON.parse(message)

    switch (data.type) {
      case 'join':
        this.handleJoin(data, sender)
        break
      case 'zone_change':
        this.handleZoneChange(data, sender)
        break
      case 'leave':
        this.handleLeave(data, sender)
        break
      case 'heartbeat':
        this.handleHeartbeat(data, sender)
        break
    }
  }

  private handleJoin(
    data: { playerId: string; displayName: string; zone: string },
    sender: Party.Connection
  ) {
    const presence: PlayerPresence = {
      playerId: data.playerId,
      displayName: data.displayName,
      zone: data.zone,
      lastSeen: Date.now(),
    }

    this.state.players.set(data.playerId, presence)

    // Notify all clients
    this.broadcast({
      type: 'player_online',
      playerId: data.playerId,
      displayName: data.displayName,
      zone: data.zone,
    })

    sender.send(JSON.stringify({ type: 'join_confirmed' }))
  }

  private handleZoneChange(data: { playerId: string; zone: string }, sender: Party.Connection) {
    const player = this.state.players.get(data.playerId)
    if (player) {
      player.zone = data.zone
      player.lastSeen = Date.now()

      this.broadcast({
        type: 'zone_changed',
        playerId: data.playerId,
        zone: data.zone,
      })
    }
  }

  private handleLeave(data: { playerId: string }, sender: Party.Connection) {
    const player = this.state.players.get(data.playerId)
    if (player) {
      this.state.players.delete(data.playerId)
      this.broadcast({
        type: 'player_offline',
        playerId: data.playerId,
        displayName: player.displayName,
      })
    }
  }

  private handleHeartbeat(data: { playerId: string }, sender: Party.Connection) {
    const player = this.state.players.get(data.playerId)
    if (player) {
      player.lastSeen = Date.now()
    }
  }

  private broadcast(message: object) {
    const json = JSON.stringify(message)
    for (const conn of this.room.getConnections()) {
      conn.send(json)
    }
  }

  // Get zone player counts
  getZoneCounts(): Record<string, number> {
    const counts: Record<string, number> = {}
    for (const player of this.state.players.values()) {
      counts[player.zone] = (counts[player.zone] || 0) + 1
    }
    return counts
  }
}

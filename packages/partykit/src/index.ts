import type * as Party from 'partykit/server'

// Main entry point - handles default room connections
// Specific rooms (market, faction, presence) are defined in their own files

export default class MainServer implements Party.Server {
  constructor(public room: Party.Room) {}

  onConnect(conn: Party.Connection) {
    conn.send(JSON.stringify({ type: 'connected', roomId: this.room.id }))
  }

  onMessage(message: string, sender: Party.Connection) {
    // Echo messages for testing
    sender.send(JSON.stringify({ type: 'echo', message }))
  }
}

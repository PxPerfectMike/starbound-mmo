import type * as Party from 'partykit/server'
import { createClient, type Database, factions, factionMembers, players, transactions } from '@starbound-mmo/db'
import { eq, and, sql } from 'drizzle-orm'
import { FACTION_CREATION_COST } from '@starbound-mmo/shared'

interface FactionState {
  factionId: string | null
  info: {
    id: string
    name: string
    tag: string
    leaderId: string
    motd: string | null
    bankCurrency: number
  } | null
  members: { playerId: string; displayName: string; role: string }[]
  onlineMembers: Set<string>
  chat: { playerId: string; displayName: string; message: string; timestamp: number }[]
}

// Each faction gets its own room, room ID = faction ID
export default class FactionServer implements Party.Server {
  private db: Database | null = null
  private state: FactionState = {
    factionId: null,
    info: null,
    members: [],
    onlineMembers: new Set(),
    chat: [],
  }

  constructor(public room: Party.Room) {
    this.state.factionId = room.id
  }

  private getDb(): Database {
    if (!this.db) {
      const databaseUrl = this.room.env.DATABASE_URL as string
      if (!databaseUrl) {
        throw new Error('DATABASE_URL environment variable not set')
      }
      this.db = createClient(databaseUrl)
    }
    return this.db
  }

  async onStart() {
    // Load faction data from database
    await this.loadFaction()
  }

  private async loadFaction() {
    if (!this.state.factionId || this.state.factionId === 'lobby') {
      return // Lobby room for faction-less operations
    }

    const db = this.getDb()

    const faction = await db.query.factions.findFirst({
      where: eq(factions.id, this.state.factionId),
    })

    if (!faction) {
      return
    }

    const members = await db.query.factionMembers.findMany({
      where: eq(factionMembers.factionId, this.state.factionId),
      with: {
        player: {
          columns: { id: true, displayName: true },
        },
      },
    })

    this.state.info = {
      id: faction.id,
      name: faction.name,
      tag: faction.tag,
      leaderId: faction.leaderId!,
      motd: faction.motd,
      bankCurrency: faction.bankCurrency,
    }

    this.state.members = members.map((m) => ({
      playerId: m.playerId,
      displayName: m.player.displayName,
      role: m.role,
    }))
  }

  onConnect(conn: Party.Connection, ctx: Party.ConnectionContext) {
    // Send current faction state
    conn.send(
      JSON.stringify({
        type: 'faction_sync',
        info: this.state.info,
        members: this.state.members,
        onlineMembers: Array.from(this.state.onlineMembers),
        recentChat: this.state.chat.slice(-50),
      })
    )
  }

  onClose(conn: Party.Connection) {
    // Would need to track connection -> playerId to properly remove
  }

  async onMessage(message: string, sender: Party.Connection) {
    const data = JSON.parse(message)

    switch (data.type) {
      case 'join_room':
        this.handleJoinRoom(data, sender)
        break
      case 'leave_room':
        this.handleLeaveRoom(data, sender)
        break
      case 'chat':
        this.handleChat(data, sender)
        break
      case 'create_faction':
        await this.handleCreateFaction(data, sender)
        break
      case 'update_motd':
        await this.handleUpdateMotd(data, sender)
        break
      case 'deposit':
        await this.handleDeposit(data, sender)
        break
      case 'kick':
        await this.handleKick(data, sender)
        break
      case 'promote':
        await this.handlePromote(data, sender)
        break
    }
  }

  private handleJoinRoom(data: { playerId: string }, sender: Party.Connection) {
    this.state.onlineMembers.add(data.playerId)
    this.broadcast({
      type: 'member_online',
      playerId: data.playerId,
    })
  }

  private handleLeaveRoom(data: { playerId: string }, sender: Party.Connection) {
    this.state.onlineMembers.delete(data.playerId)
    this.broadcast({
      type: 'member_offline',
      playerId: data.playerId,
    })
  }

  private handleChat(
    data: { playerId: string; displayName: string; message: string },
    sender: Party.Connection
  ) {
    const chatMessage = {
      playerId: data.playerId,
      displayName: data.displayName,
      message: data.message,
      timestamp: Date.now(),
    }

    this.state.chat.push(chatMessage)

    // Keep only last 100 messages in memory
    if (this.state.chat.length > 100) {
      this.state.chat = this.state.chat.slice(-100)
    }

    this.broadcast({
      type: 'chat_message',
      ...chatMessage,
    })
  }

  private async handleCreateFaction(
    data: { playerId: string; name: string; tag: string },
    sender: Party.Connection
  ) {
    // This is called from the lobby room
    const db = this.getDb()

    try {
      // Check if player has enough currency
      const player = await db.query.players.findFirst({
        where: eq(players.id, data.playerId),
      })

      if (!player) {
        sender.send(JSON.stringify({ type: 'error', message: 'Player not found' }))
        return
      }

      if (player.currency < FACTION_CREATION_COST) {
        sender.send(JSON.stringify({ type: 'error', message: 'Insufficient funds' }))
        return
      }

      // Check if name/tag already exists
      const existingByName = await db.query.factions.findFirst({
        where: eq(factions.name, data.name),
      })
      if (existingByName) {
        sender.send(JSON.stringify({ type: 'error', message: 'Faction name already taken' }))
        return
      }

      const existingByTag = await db.query.factions.findFirst({
        where: eq(factions.tag, data.tag),
      })
      if (existingByTag) {
        sender.send(JSON.stringify({ type: 'error', message: 'Faction tag already taken' }))
        return
      }

      // Deduct creation cost
      await db
        .update(players)
        .set({ currency: sql`${players.currency} - ${FACTION_CREATION_COST}` })
        .where(eq(players.id, data.playerId))

      // Record transaction
      await db.insert(transactions).values({
        type: 'faction_deposit',
        playerId: data.playerId,
        amount: -FACTION_CREATION_COST,
        metadata: { action: 'faction_creation', name: data.name },
      })

      // Create faction
      const [newFaction] = await db
        .insert(factions)
        .values({
          name: data.name,
          tag: data.tag,
          leaderId: data.playerId,
        })
        .returning()

      // Add creator as leader member
      await db.insert(factionMembers).values({
        factionId: newFaction.id,
        playerId: data.playerId,
        role: 'leader',
      })

      // Update player's faction
      await db.update(players).set({ factionId: newFaction.id }).where(eq(players.id, data.playerId))

      sender.send(
        JSON.stringify({
          type: 'faction_created',
          faction: newFaction,
        })
      )
    } catch (error) {
      console.error('Error creating faction:', error)
      sender.send(JSON.stringify({ type: 'error', message: 'Failed to create faction' }))
    }
  }

  private async handleUpdateMotd(data: { playerId: string; motd: string }, sender: Party.Connection) {
    const db = this.getDb()

    // Verify player is leader or officer
    const member = this.state.members.find((m) => m.playerId === data.playerId)
    if (!member || (member.role !== 'leader' && member.role !== 'officer')) {
      sender.send(JSON.stringify({ type: 'error', message: 'Not authorized' }))
      return
    }

    await db
      .update(factions)
      .set({ motd: data.motd })
      .where(eq(factions.id, this.state.factionId!))

    if (this.state.info) {
      this.state.info.motd = data.motd
    }

    this.broadcast({
      type: 'motd_updated',
      motd: data.motd,
    })
  }

  private async handleDeposit(data: { playerId: string; amount: number }, sender: Party.Connection) {
    const db = this.getDb()

    try {
      // Verify player is a member
      const isMember = this.state.members.some((m) => m.playerId === data.playerId)
      if (!isMember) {
        sender.send(JSON.stringify({ type: 'error', message: 'Not a faction member' }))
        return
      }

      // Get player and check funds
      const player = await db.query.players.findFirst({
        where: eq(players.id, data.playerId),
      })

      if (!player || player.currency < data.amount) {
        sender.send(JSON.stringify({ type: 'error', message: 'Insufficient funds' }))
        return
      }

      // Deduct from player
      await db
        .update(players)
        .set({ currency: sql`${players.currency} - ${data.amount}` })
        .where(eq(players.id, data.playerId))

      // Add to faction bank
      await db
        .update(factions)
        .set({ bankCurrency: sql`${factions.bankCurrency} + ${data.amount}` })
        .where(eq(factions.id, this.state.factionId!))

      // Record transaction
      await db.insert(transactions).values({
        type: 'faction_deposit',
        playerId: data.playerId,
        amount: -data.amount,
        metadata: { factionId: this.state.factionId },
      })

      if (this.state.info) {
        this.state.info.bankCurrency += data.amount
      }

      this.broadcast({
        type: 'bank_updated',
        bankCurrency: this.state.info?.bankCurrency ?? 0,
        depositor: data.playerId,
        amount: data.amount,
      })

      sender.send(JSON.stringify({ type: 'deposit_complete', amount: data.amount }))
    } catch (error) {
      console.error('Error processing deposit:', error)
      sender.send(JSON.stringify({ type: 'error', message: 'Failed to deposit' }))
    }
  }

  private async handleKick(data: { playerId: string; targetPlayerId: string }, sender: Party.Connection) {
    const db = this.getDb()

    // Verify kicker is leader
    const kicker = this.state.members.find((m) => m.playerId === data.playerId)
    if (!kicker || kicker.role !== 'leader') {
      sender.send(JSON.stringify({ type: 'error', message: 'Only the leader can kick members' }))
      return
    }

    // Can't kick yourself
    if (data.playerId === data.targetPlayerId) {
      sender.send(JSON.stringify({ type: 'error', message: 'Cannot kick yourself' }))
      return
    }

    // Remove from faction_members
    await db
      .delete(factionMembers)
      .where(
        and(
          eq(factionMembers.factionId, this.state.factionId!),
          eq(factionMembers.playerId, data.targetPlayerId)
        )
      )

    // Clear player's faction
    await db.update(players).set({ factionId: null }).where(eq(players.id, data.targetPlayerId))

    // Update local state
    this.state.members = this.state.members.filter((m) => m.playerId !== data.targetPlayerId)
    this.state.onlineMembers.delete(data.targetPlayerId)

    this.broadcast({
      type: 'member_kicked',
      playerId: data.targetPlayerId,
    })
  }

  private async handlePromote(
    data: { playerId: string; targetPlayerId: string; role: 'officer' | 'member' },
    sender: Party.Connection
  ) {
    const db = this.getDb()

    // Verify promoter is leader
    const promoter = this.state.members.find((m) => m.playerId === data.playerId)
    if (!promoter || promoter.role !== 'leader') {
      sender.send(JSON.stringify({ type: 'error', message: 'Only the leader can change roles' }))
      return
    }

    await db
      .update(factionMembers)
      .set({ role: data.role })
      .where(
        and(
          eq(factionMembers.factionId, this.state.factionId!),
          eq(factionMembers.playerId, data.targetPlayerId)
        )
      )

    // Update local state
    const member = this.state.members.find((m) => m.playerId === data.targetPlayerId)
    if (member) {
      member.role = data.role
    }

    this.broadcast({
      type: 'member_role_changed',
      playerId: data.targetPlayerId,
      role: data.role,
    })
  }

  private broadcast(message: object) {
    const json = JSON.stringify(message)
    for (const conn of this.room.getConnections()) {
      conn.send(json)
    }
  }
}

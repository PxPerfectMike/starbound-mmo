import { createClient, players, pendingItems } from '@starbound-mmo/db'
import { eq, sql } from 'drizzle-orm'
import type { CommandType, CommandData } from '@starbound-mmo/shared'
import { STARTING_CURRENCY } from '@starbound-mmo/shared'
import type { PartyKitClient } from './partykit.js'
import type { StateWriter } from './state.js'

type ValidatedCommand<T extends CommandType> = {
  id: string
  type: T
  playerId: string
  timestamp: number
  data: CommandData[T]
}

export function createCommandRouter(
  databaseUrl: string,
  partykit: PartyKitClient,
  stateWriter: StateWriter
) {
  const db = createClient(databaseUrl)

  async function handleCommand(command: {
    id: string
    type: CommandType
    playerId: string
    timestamp: number
    data: unknown
  }) {
    switch (command.type) {
      case 'player_join':
        await handlePlayerJoin(command as ValidatedCommand<'player_join'>)
        break
      case 'player_leave':
        await handlePlayerLeave(command as ValidatedCommand<'player_leave'>)
        break
      case 'market_create':
        await handleMarketCreate(command as ValidatedCommand<'market_create'>)
        break
      case 'market_purchase':
        await handleMarketPurchase(command as ValidatedCommand<'market_purchase'>)
        break
      case 'market_cancel':
        await handleMarketCancel(command as ValidatedCommand<'market_cancel'>)
        break
      case 'faction_create':
        await handleFactionCreate(command as ValidatedCommand<'faction_create'>)
        break
      case 'faction_join':
        await handleFactionJoin(command as ValidatedCommand<'faction_join'>)
        break
      case 'faction_leave':
        await handleFactionLeave(command as ValidatedCommand<'faction_leave'>)
        break
      case 'faction_deposit':
        await handleFactionDeposit(command as ValidatedCommand<'faction_deposit'>)
        break
      default:
        console.warn(`Unknown command type: ${command.type}`)
    }
  }

  async function handlePlayerJoin(command: ValidatedCommand<'player_join'>) {
    const { playerId, data } = command

    // Check if player exists
    let player = await db.query.players.findFirst({
      where: eq(players.starboundId, data.starboundId),
    })

    if (!player) {
      // Create new player
      const [newPlayer] = await db
        .insert(players)
        .values({
          starboundId: data.starboundId,
          displayName: data.displayName,
          currency: STARTING_CURRENCY,
        })
        .returning()
      player = newPlayer
      console.log(`Created new player: ${player.displayName}`)
    } else {
      // Update last seen
      await db
        .update(players)
        .set({
          lastSeenAt: new Date(),
          displayName: data.displayName, // Update display name if changed
        })
        .where(eq(players.id, player.id))
      console.log(`Player rejoined: ${player.displayName}`)
    }

    // Get pending items for this player
    const pending = await db.query.pendingItems.findMany({
      where: eq(pendingItems.playerId, player.id),
    })

    // Write player state file
    await stateWriter.writePlayerState(player.id, {
      id: player.id,
      displayName: player.displayName,
      currency: player.currency,
      factionId: player.factionId,
      factionTag: null, // Would need to look up faction
      pendingItems: pending.map((p) => ({
        id: p.id,
        itemName: p.itemName,
        itemCount: p.itemCount,
        itemParams: p.itemParams as Record<string, unknown>,
        source: p.source as 'market_purchase' | 'market_return' | 'event_reward',
        createdAt: p.createdAt.toISOString(),
      })),
      notifications: [],
    })

    // Notify presence
    partykit.sendToPresence({
      type: 'join',
      playerId: player.id,
      displayName: player.displayName,
      zone: 'hub', // Default to hub
    })
  }

  async function handlePlayerLeave(command: ValidatedCommand<'player_leave'>) {
    partykit.sendToPresence({
      type: 'leave',
      playerId: command.playerId,
    })
  }

  async function handleMarketCreate(command: ValidatedCommand<'market_create'>) {
    // Forward to PartyKit market room
    partykit.sendToMarket({
      type: 'create_listing',
      playerId: command.playerId,
      itemName: command.data.item.name,
      itemCount: command.data.item.count,
      itemParams: command.data.item.parameters,
      pricePerUnit: command.data.pricePerUnit,
    })
  }

  async function handleMarketPurchase(command: ValidatedCommand<'market_purchase'>) {
    partykit.sendToMarket({
      type: 'purchase',
      playerId: command.playerId,
      listingId: command.data.listingId,
    })
  }

  async function handleMarketCancel(command: ValidatedCommand<'market_cancel'>) {
    partykit.sendToMarket({
      type: 'cancel',
      playerId: command.playerId,
      listingId: command.data.listingId,
    })
  }

  async function handleFactionCreate(command: ValidatedCommand<'faction_create'>) {
    // Use the lobby faction room for creation
    partykit.sendToFaction('lobby', {
      type: 'create_faction',
      playerId: command.playerId,
      name: command.data.name,
      tag: command.data.tag,
    })
  }

  async function handleFactionJoin(command: ValidatedCommand<'faction_join'>) {
    partykit.sendToFaction(command.data.factionId, {
      type: 'join_request',
      playerId: command.playerId,
    })
  }

  async function handleFactionLeave(command: ValidatedCommand<'faction_leave'>) {
    // Get player's current faction
    const player = await db.query.players.findFirst({
      where: eq(players.id, command.playerId),
    })

    if (player?.factionId) {
      partykit.sendToFaction(player.factionId, {
        type: 'leave',
        playerId: command.playerId,
      })
    }
  }

  async function handleFactionDeposit(command: ValidatedCommand<'faction_deposit'>) {
    const player = await db.query.players.findFirst({
      where: eq(players.id, command.playerId),
    })

    if (player?.factionId) {
      partykit.sendToFaction(player.factionId, {
        type: 'deposit',
        playerId: command.playerId,
        amount: command.data.amount,
      })
    }
  }

  // Subscribe to market updates to sync player states
  partykit.onMarketMessage(async (data: unknown) => {
    const message = data as { type: string; [key: string]: unknown }

    if (message.type === 'listing_sold' || message.type === 'purchase_complete') {
      // Update player currency in state files
      // This would need more sophisticated handling in production
      console.log('Market transaction completed, updating player states')
    }
  })

  return { handleCommand }
}

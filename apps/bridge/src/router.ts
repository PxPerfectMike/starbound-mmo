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
      case 'claim_item':
        await handleClaimItem(command as ValidatedCommand<'claim_item'>)
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

    // Write player state file (use starboundId so Lua can read it)
    await stateWriter.writePlayerState(player.id, data.starboundId, {
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
    console.log(`[Router] Processing market purchase: listing ${command.data.listingId} by player ${command.playerId}`)
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

  async function handleClaimItem(command: ValidatedCommand<'claim_item'>) {
    const { playerId, data } = command

    try {
      // Delete the pending item from database
      const deleted = await db
        .delete(pendingItems)
        .where(eq(pendingItems.id, data.pendingItemId))
        .returning()

      if (deleted.length > 0) {
        console.log(`[Router] Claimed item ${data.pendingItemId} for player ${playerId}`)

        // Get updated player state and write it
        const player = await db.query.players.findFirst({
          where: eq(players.id, playerId),
        })

        if (player) {
          const remaining = await db.query.pendingItems.findMany({
            where: eq(pendingItems.playerId, playerId),
          })

          await stateWriter.writePlayerState(player.id, player.starboundId, {
            id: player.id,
            displayName: player.displayName,
            currency: player.currency,
            factionId: player.factionId,
            factionTag: null,
            pendingItems: remaining.map((p) => ({
              id: p.id,
              itemName: p.itemName,
              itemCount: p.itemCount,
              itemParams: p.itemParams as Record<string, unknown>,
              source: p.source as 'market_purchase' | 'market_return' | 'event_reward',
              createdAt: p.createdAt.toISOString(),
            })),
            notifications: [],
          })

          console.log(`[Router] Updated player state: ${remaining.length} items remaining`)
        }
      } else {
        console.warn(`[Router] Pending item not found: ${data.pendingItemId}`)
      }
    } catch (error) {
      console.error('[Router] Error claiming item:', error)
    }
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
    const message = data as {
      type: string
      listing?: {
        id: string
        sellerId: string
        itemName: string
        itemCount: number
        itemParams: Record<string, unknown>
        totalPrice: number
      }
      newBalance?: number
      buyerId?: string
    }

    if (message.type === 'purchase_complete' && message.listing) {
      console.log('Purchase complete, updating buyer state')

      // Find the buyer - we need to look up by the listing that was just sold
      // The purchase was initiated by a command, so we need to refresh buyer data
      try {
        // Get all players and find the one who just bought (has pending item for this listing)
        const allPendingItems = await db.query.pendingItems.findMany({
          where: eq(pendingItems.itemName, message.listing.itemName),
          with: { player: true },
          orderBy: (items, { desc }) => [desc(items.createdAt)],
          limit: 1,
        })

        if (allPendingItems.length > 0) {
          const pending = allPendingItems[0]
          const buyer = pending.player

          // Get all pending items for this buyer
          const buyerPendingItems = await db.query.pendingItems.findMany({
            where: eq(pendingItems.playerId, buyer.id),
          })

          // Write updated player state
          await stateWriter.writePlayerState(buyer.id, buyer.starboundId, {
            id: buyer.id,
            displayName: buyer.displayName,
            currency: buyer.currency,
            factionId: buyer.factionId,
            factionTag: null,
            pendingItems: buyerPendingItems.map((p) => ({
              id: p.id,
              itemName: p.itemName,
              itemCount: p.itemCount,
              itemParams: p.itemParams as Record<string, unknown>,
              source: p.source as 'market_purchase' | 'market_return' | 'event_reward',
              createdAt: p.createdAt.toISOString(),
            })),
            notifications: [{
              id: `purchase-${message.listing.id}`,
              type: 'market_purchase',
              message: `Purchased ${message.listing.itemCount}x ${message.listing.itemName}`,
              createdAt: new Date().toISOString(),
            }],
          })

          console.log(`Updated buyer state for ${buyer.displayName}: ${buyer.currency} CR, ${buyerPendingItems.length} pending items`)
        }
      } catch (error) {
        console.error('Error updating buyer state:', error)
      }
    }

    if (message.type === 'listing_sold' && message.listing) {
      console.log('Listing sold, updating seller state')

      try {
        // Update seller state
        const seller = await db.query.players.findFirst({
          where: eq(players.id, message.listing.sellerId),
        })

        if (seller) {
          const sellerPendingItems = await db.query.pendingItems.findMany({
            where: eq(pendingItems.playerId, seller.id),
          })

          await stateWriter.writePlayerState(seller.id, seller.starboundId, {
            id: seller.id,
            displayName: seller.displayName,
            currency: seller.currency,
            factionId: seller.factionId,
            factionTag: null,
            pendingItems: sellerPendingItems.map((p) => ({
              id: p.id,
              itemName: p.itemName,
              itemCount: p.itemCount,
              itemParams: p.itemParams as Record<string, unknown>,
              source: p.source as 'market_purchase' | 'market_return' | 'event_reward',
              createdAt: p.createdAt.toISOString(),
            })),
            notifications: [{
              id: `sale-${message.listing.id}`,
              type: 'market_sale',
              message: `Sold ${message.listing.itemCount}x ${message.listing.itemName} for ${message.listing.totalPrice} CR`,
              createdAt: new Date().toISOString(),
            }],
          })

          console.log(`Updated seller state for ${seller.displayName}: ${seller.currency} CR`)
        }
      } catch (error) {
        console.error('Error updating seller state:', error)
      }
    }
  })

  return { handleCommand }
}

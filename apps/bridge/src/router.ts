import { createClient, players, pendingItems } from '@starbound-mmo/db'
import { eq, inArray } from 'drizzle-orm'
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

interface CachedPlayer {
  id: string
  starboundId: string
  displayName: string
  currency: number
  factionId: string | null
  cachedAt: number
}

const CACHE_TTL_MS = 5 * 60 * 1000 // 5 minutes

export function createCommandRouter(
  databaseUrl: string,
  partykit: PartyKitClient,
  stateWriter: StateWriter
) {
  const db = createClient(databaseUrl)
  const playerCache = new Map<string, CachedPlayer>()

  /**
   * Resolve a starboundId (character UUID from Lua) to a full player record with DB UUID.
   * Results are cached for 5 minutes.
   */
  async function resolvePlayer(starboundId: string): Promise<CachedPlayer | null> {
    const cached = playerCache.get(starboundId)
    if (cached && Date.now() - cached.cachedAt < CACHE_TTL_MS) {
      return cached
    }

    const player = await db.query.players.findFirst({
      where: eq(players.starboundId, starboundId),
    })

    if (!player) return null

    const entry: CachedPlayer = {
      id: player.id,
      starboundId: player.starboundId,
      displayName: player.displayName,
      currency: player.currency,
      factionId: player.factionId,
      cachedAt: Date.now(),
    }
    playerCache.set(starboundId, entry)
    return entry
  }

  /**
   * Attach seller.starboundId to market listings that lack it (older PartyKit deploys
   * only send seller id + displayName). The in-game UI needs the character UUID to
   * recognize its own listings.
   */
  async function attachSellerStarboundIds(listings: unknown[]): Promise<unknown[]> {
    type Listing = { sellerId?: string; seller?: { id?: string; displayName?: string; starboundId?: string } }
    const missing = new Set<string>()
    for (const raw of listings as Listing[]) {
      if (raw.seller?.starboundId) continue
      const sellerId = raw.seller?.id ?? raw.sellerId
      if (sellerId) missing.add(sellerId)
    }
    if (missing.size === 0) return listings

    const rows = await db.query.players.findMany({
      where: inArray(players.id, Array.from(missing)),
      columns: { id: true, starboundId: true },
    })
    const byId = new Map(rows.map((r) => [r.id, r.starboundId]))

    return (listings as Listing[]).map((raw) => {
      if (raw.seller?.starboundId) return raw
      const sellerId = raw.seller?.id ?? raw.sellerId
      const starboundId = sellerId ? byId.get(sellerId) : undefined
      if (!starboundId) return raw
      return { ...raw, seller: { ...(raw.seller ?? { id: sellerId }), starboundId } }
    })
  }

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
    // command.playerId is the starboundId (character UUID from Lua)
    const starboundId = command.playerId
    const { data } = command

    // Check if player exists
    let player = await db.query.players.findFirst({
      where: eq(players.starboundId, starboundId),
    })

    if (!player) {
      // Create new player
      const [newPlayer] = await db
        .insert(players)
        .values({
          starboundId,
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

    // Cache the resolved player
    playerCache.set(starboundId, {
      id: player.id,
      starboundId: player.starboundId,
      displayName: player.displayName,
      currency: player.currency,
      factionId: player.factionId,
      cachedAt: Date.now(),
    })

    // Get pending items for this player
    const pending = await db.query.pendingItems.findMany({
      where: eq(pendingItems.playerId, player.id),
    })

    // Write player state file (use starboundId so Lua can read it)
    await stateWriter.writePlayerState(player.id, starboundId, {
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
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for leave: ${command.playerId}`)
      return
    }
    partykit.sendToPresence({
      type: 'leave',
      playerId: resolved.id,
    })
  }

  async function handleMarketCreate(command: ValidatedCommand<'market_create'>) {
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for market_create: ${command.playerId}`)
      return
    }
    partykit.sendToMarket({
      type: 'create_listing',
      playerId: resolved.id,
      itemName: command.data.item.name,
      itemCount: command.data.item.count,
      itemParams: command.data.item.parameters,
      pricePerUnit: command.data.pricePerUnit,
    })
  }

  async function handleMarketPurchase(command: ValidatedCommand<'market_purchase'>) {
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for market_purchase: ${command.playerId}`)
      return
    }
    console.log(`[Router] Processing market purchase: listing ${command.data.listingId} by player ${resolved.id}`)
    partykit.sendToMarket({
      type: 'purchase',
      playerId: resolved.id,
      listingId: command.data.listingId,
    })
  }

  async function handleMarketCancel(command: ValidatedCommand<'market_cancel'>) {
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for market_cancel: ${command.playerId}`)
      return
    }
    partykit.sendToMarket({
      type: 'cancel',
      playerId: resolved.id,
      listingId: command.data.listingId,
    })
  }

  async function handleClaimItem(command: ValidatedCommand<'claim_item'>) {
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for claim_item: ${command.playerId}`)
      return
    }

    try {
      // Delete the pending item from database
      const deleted = await db
        .delete(pendingItems)
        .where(eq(pendingItems.id, command.data.pendingItemId))
        .returning()

      if (deleted.length > 0) {
        console.log(`[Router] Claimed item ${command.data.pendingItemId} for player ${resolved.id}`)

        // Get updated player state and write it
        const player = await db.query.players.findFirst({
          where: eq(players.id, resolved.id),
        })

        if (player) {
          const remaining = await db.query.pendingItems.findMany({
            where: eq(pendingItems.playerId, resolved.id),
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
        console.warn(`[Router] Pending item not found: ${command.data.pendingItemId}`)
      }
    } catch (error) {
      console.error('[Router] Error claiming item:', error)
    }
  }

  async function handleFactionCreate(command: ValidatedCommand<'faction_create'>) {
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for faction_create: ${command.playerId}`)
      return
    }
    partykit.sendToFaction('lobby', {
      type: 'create_faction',
      playerId: resolved.id,
      name: command.data.name,
      tag: command.data.tag,
    })
  }

  async function handleFactionJoin(command: ValidatedCommand<'faction_join'>) {
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for faction_join: ${command.playerId}`)
      return
    }
    partykit.sendToFaction(command.data.factionId, {
      type: 'join_request',
      playerId: resolved.id,
    })
  }

  async function handleFactionLeave(command: ValidatedCommand<'faction_leave'>) {
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for faction_leave: ${command.playerId}`)
      return
    }

    if (resolved.factionId) {
      partykit.sendToFaction(resolved.factionId, {
        type: 'leave',
        playerId: resolved.id,
      })
    }
  }

  async function handleFactionDeposit(command: ValidatedCommand<'faction_deposit'>) {
    const resolved = await resolvePlayer(command.playerId)
    if (!resolved) {
      console.warn(`[Router] Unknown player for faction_deposit: ${command.playerId}`)
      return
    }

    if (resolved.factionId) {
      partykit.sendToFaction(resolved.factionId, {
        type: 'deposit',
        playerId: resolved.id,
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
              type: 'success',
              message: `Purchased ${message.listing.itemCount}x ${message.listing.itemName}`,
              createdAt: new Date().toISOString(),
            }],
          })

          console.log(`Updated buyer state for ${buyer.displayName}: ${buyer.currency} PX, ${buyerPendingItems.length} pending items`)
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
              type: 'success',
              message: `Sold ${message.listing.itemCount}x ${message.listing.itemName} for ${message.listing.totalPrice} PX`,
              createdAt: new Date().toISOString(),
            }],
          })

          console.log(`Updated seller state for ${seller.displayName}: ${seller.currency} PX`)
        }
      } catch (error) {
        console.error('Error updating seller state:', error)
      }
    }
  })

  return { handleCommand, attachSellerStarboundIds }
}

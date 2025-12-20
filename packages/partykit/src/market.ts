import type * as Party from 'partykit/server'
import { createClient, type Database, marketListings, players, transactions, pendingItems } from '@starbound-mmo/db'
import { eq, and, sql } from 'drizzle-orm'
import type { MarketListingWithSeller, MarketSyncMessage, MarketUpdateMessage } from '@starbound-mmo/shared'
import { LISTING_DURATION_DAYS, LISTING_FEE_PERCENT } from '@starbound-mmo/shared'

interface MarketState {
  listings: MarketListingWithSeller[]
}

export default class MarketServer implements Party.Server {
  private db: Database | null = null
  private state: MarketState = { listings: [] }

  constructor(public room: Party.Room) {}

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
    // Load active listings from database on startup
    await this.loadListings()
  }

  private async loadListings() {
    const db = this.getDb()
    const now = new Date()

    // First, expire any old listings
    await db
      .update(marketListings)
      .set({ status: 'expired' })
      .where(and(eq(marketListings.status, 'active'), sql`${marketListings.expiresAt} < ${now}`))

    // Load active listings with seller info
    const listings = await db.query.marketListings.findMany({
      where: eq(marketListings.status, 'active'),
      with: {
        seller: {
          columns: {
            id: true,
            displayName: true,
          },
        },
      },
      orderBy: (listings, { desc }) => [desc(listings.createdAt)],
    })

    this.state.listings = listings.map((l) => ({
      id: l.id,
      sellerId: l.sellerId,
      itemName: l.itemName,
      itemCount: l.itemCount,
      itemParams: l.itemParams as Record<string, unknown>,
      pricePerUnit: l.pricePerUnit,
      totalPrice: l.totalPrice,
      status: l.status as 'active',
      createdAt: l.createdAt,
      expiresAt: l.expiresAt,
      seller: l.seller,
    }))
  }

  onConnect(conn: Party.Connection) {
    // Send current listings to new connection
    const syncMessage: MarketSyncMessage = {
      type: 'sync',
      listings: this.state.listings,
    }
    conn.send(JSON.stringify(syncMessage))
  }

  async onMessage(message: string, sender: Party.Connection) {
    const data = JSON.parse(message)

    switch (data.type) {
      case 'create_listing':
        await this.handleCreateListing(data, sender)
        break
      case 'purchase':
        await this.handlePurchase(data, sender)
        break
      case 'cancel':
        await this.handleCancel(data, sender)
        break
      case 'refresh':
        await this.loadListings()
        this.broadcast({ type: 'sync', listings: this.state.listings })
        break
    }
  }

  private async handleCreateListing(
    data: {
      playerId: string
      itemName: string
      itemCount: number
      itemParams: Record<string, unknown>
      pricePerUnit: number
    },
    sender: Party.Connection
  ) {
    const db = this.getDb()

    try {
      // Get player and verify they exist
      const player = await db.query.players.findFirst({
        where: eq(players.id, data.playerId),
      })

      if (!player) {
        sender.send(JSON.stringify({ type: 'error', message: 'Player not found' }))
        return
      }

      // Calculate listing fee
      const totalPrice = data.pricePerUnit * data.itemCount
      const listingFee = Math.floor((totalPrice * LISTING_FEE_PERCENT) / 100)

      if (player.currency < listingFee) {
        sender.send(JSON.stringify({ type: 'error', message: 'Insufficient funds for listing fee' }))
        return
      }

      // Calculate expiration date
      const expiresAt = new Date()
      expiresAt.setDate(expiresAt.getDate() + LISTING_DURATION_DAYS)

      // Create the listing and deduct fee in a transaction-like flow
      // Note: Neon serverless doesn't support true transactions, but we can minimize race conditions

      // Deduct listing fee
      await db
        .update(players)
        .set({ currency: sql`${players.currency} - ${listingFee}` })
        .where(eq(players.id, data.playerId))

      // Record transaction
      await db.insert(transactions).values({
        type: 'market_listing_fee',
        playerId: data.playerId,
        amount: -listingFee,
        metadata: { itemName: data.itemName, itemCount: data.itemCount },
      })

      // Create listing
      const [newListing] = await db
        .insert(marketListings)
        .values({
          sellerId: data.playerId,
          itemName: data.itemName,
          itemCount: data.itemCount,
          itemParams: data.itemParams,
          pricePerUnit: data.pricePerUnit,
          totalPrice,
          expiresAt,
        })
        .returning()

      // Add to local state
      const listingWithSeller: MarketListingWithSeller = {
        ...newListing,
        itemParams: newListing.itemParams as Record<string, unknown>,
        status: newListing.status as 'active',
        seller: { id: player.id, displayName: player.displayName },
      }
      this.state.listings.unshift(listingWithSeller)

      // Broadcast to all clients
      const updateMessage: MarketUpdateMessage = {
        type: 'listing_added',
        listing: listingWithSeller,
      }
      this.broadcast(updateMessage)

      sender.send(JSON.stringify({ type: 'listing_created', listing: listingWithSeller }))
    } catch (error) {
      console.error('Error creating listing:', error)
      sender.send(JSON.stringify({ type: 'error', message: 'Failed to create listing' }))
    }
  }

  private async handlePurchase(data: { playerId: string; listingId: string }, sender: Party.Connection) {
    const db = this.getDb()

    try {
      // Get the listing
      const listing = await db.query.marketListings.findFirst({
        where: and(eq(marketListings.id, data.listingId), eq(marketListings.status, 'active')),
        with: { seller: true },
      })

      if (!listing) {
        sender.send(JSON.stringify({ type: 'error', message: 'Listing not found or no longer available' }))
        return
      }

      // Can't buy your own listing
      if (listing.sellerId === data.playerId) {
        sender.send(JSON.stringify({ type: 'error', message: 'Cannot purchase your own listing' }))
        return
      }

      // Get buyer
      const buyer = await db.query.players.findFirst({
        where: eq(players.id, data.playerId),
      })

      if (!buyer) {
        sender.send(JSON.stringify({ type: 'error', message: 'Buyer not found' }))
        return
      }

      if (buyer.currency < listing.totalPrice) {
        sender.send(JSON.stringify({ type: 'error', message: 'Insufficient funds' }))
        return
      }

      // Process the purchase
      // 1. Mark listing as sold
      await db
        .update(marketListings)
        .set({ status: 'sold' })
        .where(eq(marketListings.id, data.listingId))

      // 2. Deduct from buyer
      await db
        .update(players)
        .set({ currency: sql`${players.currency} - ${listing.totalPrice}` })
        .where(eq(players.id, data.playerId))

      // 3. Credit seller
      await db
        .update(players)
        .set({ currency: sql`${players.currency} + ${listing.totalPrice}` })
        .where(eq(players.id, listing.sellerId))

      // 4. Create pending item for buyer
      await db.insert(pendingItems).values({
        playerId: data.playerId,
        itemName: listing.itemName,
        itemCount: listing.itemCount,
        itemParams: listing.itemParams,
        source: 'market_purchase',
      })

      // 5. Record transactions
      await db.insert(transactions).values([
        {
          type: 'market_purchase',
          playerId: data.playerId,
          amount: -listing.totalPrice,
          metadata: { listingId: listing.id, itemName: listing.itemName },
        },
        {
          type: 'market_sale',
          playerId: listing.sellerId,
          amount: listing.totalPrice,
          metadata: { listingId: listing.id, itemName: listing.itemName, buyerId: data.playerId },
        },
      ])

      // Remove from local state
      this.state.listings = this.state.listings.filter((l) => l.id !== data.listingId)

      // Broadcast update
      const soldListing: MarketListingWithSeller = {
        ...listing,
        itemParams: listing.itemParams as Record<string, unknown>,
        status: 'sold',
        seller: { id: listing.seller.id, displayName: listing.seller.displayName },
      }

      this.broadcast({ type: 'listing_sold', listing: soldListing })

      sender.send(
        JSON.stringify({
          type: 'purchase_complete',
          listing: soldListing,
          newBalance: buyer.currency - listing.totalPrice,
        })
      )
    } catch (error) {
      console.error('Error processing purchase:', error)
      sender.send(JSON.stringify({ type: 'error', message: 'Failed to process purchase' }))
    }
  }

  private async handleCancel(data: { playerId: string; listingId: string }, sender: Party.Connection) {
    const db = this.getDb()

    try {
      // Get the listing
      const listing = await db.query.marketListings.findFirst({
        where: and(
          eq(marketListings.id, data.listingId),
          eq(marketListings.status, 'active'),
          eq(marketListings.sellerId, data.playerId)
        ),
        with: { seller: true },
      })

      if (!listing) {
        sender.send(JSON.stringify({ type: 'error', message: 'Listing not found or not owned by you' }))
        return
      }

      // Cancel the listing
      await db
        .update(marketListings)
        .set({ status: 'cancelled' })
        .where(eq(marketListings.id, data.listingId))

      // Return items to seller via pending items
      await db.insert(pendingItems).values({
        playerId: data.playerId,
        itemName: listing.itemName,
        itemCount: listing.itemCount,
        itemParams: listing.itemParams,
        source: 'market_return',
      })

      // Remove from local state
      this.state.listings = this.state.listings.filter((l) => l.id !== data.listingId)

      // Broadcast update
      const cancelledListing: MarketListingWithSeller = {
        ...listing,
        itemParams: listing.itemParams as Record<string, unknown>,
        status: 'cancelled',
        seller: { id: listing.seller.id, displayName: listing.seller.displayName },
      }

      this.broadcast({ type: 'listing_removed', listing: cancelledListing })

      sender.send(JSON.stringify({ type: 'cancel_complete', listing: cancelledListing }))
    } catch (error) {
      console.error('Error cancelling listing:', error)
      sender.send(JSON.stringify({ type: 'error', message: 'Failed to cancel listing' }))
    }
  }

  private broadcast(message: object) {
    const json = JSON.stringify(message)
    for (const conn of this.room.getConnections()) {
      conn.send(json)
    }
  }
}

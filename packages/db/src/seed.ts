import 'dotenv/config'
import { drizzle } from 'drizzle-orm/neon-http'
import { neon } from '@neondatabase/serverless'
import { eq } from 'drizzle-orm'
import { players, marketListings } from './schema.js'

const sql = neon(process.env.DATABASE_URL!)
const db = drizzle(sql)

async function seed() {
  console.log('Seeding database...')

  // Clear existing test data
  console.log('Clearing existing test data...')
  await db.delete(marketListings)
  await db.delete(players).where(eq(players.starboundId, 'test-player-1'))
  await db.delete(players).where(eq(players.starboundId, 'test-player-2'))
  await db.delete(players).where(eq(players.starboundId, 'test-player-3'))

  // Create test players
  const [player1] = await db
    .insert(players)
    .values({
      starboundId: 'test-player-1',
      displayName: 'SpaceCaptain',
      currency: 5000,
    })
    .returning()

  const [player2] = await db
    .insert(players)
    .values({
      starboundId: 'test-player-2',
      displayName: 'StarTrader',
      currency: 10000,
    })
    .returning()

  const [player3] = await db
    .insert(players)
    .values({
      starboundId: 'test-player-3',
      displayName: 'NovaMiner',
      currency: 2500,
    })
    .returning()

  console.log('Created test players:', player1.displayName, player2.displayName, player3.displayName)

  // Create test market listings
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days from now

  const listings = await db
    .insert(marketListings)
    .values([
      {
        sellerId: player1.id,
        itemName: 'Refined Aegisalt',
        itemCount: 50,
        pricePerUnit: 25,
        totalPrice: 1250,
        expiresAt,
      },
      {
        sellerId: player1.id,
        itemName: 'Diamond',
        itemCount: 10,
        pricePerUnit: 500,
        totalPrice: 5000,
        expiresAt,
      },
      {
        sellerId: player2.id,
        itemName: 'Fuel Cell',
        itemCount: 100,
        pricePerUnit: 15,
        totalPrice: 1500,
        expiresAt,
      },
      {
        sellerId: player2.id,
        itemName: 'Titanium Bar',
        itemCount: 200,
        pricePerUnit: 8,
        totalPrice: 1600,
        expiresAt,
      },
      {
        sellerId: player3.id,
        itemName: 'Solarium Star',
        itemCount: 5,
        pricePerUnit: 1000,
        totalPrice: 5000,
        expiresAt,
      },
      {
        sellerId: player3.id,
        itemName: 'Core Fragment',
        itemCount: 25,
        pricePerUnit: 40,
        totalPrice: 1000,
        expiresAt,
      },
    ])
    .returning()

  console.log(`Created ${listings.length} market listings`)
  console.log('Seed complete!')
}

seed().catch(console.error)

import {
  pgTable,
  uuid,
  text,
  bigint,
  integer,
  boolean,
  timestamp,
  jsonb,
  primaryKey,
  index,
} from 'drizzle-orm/pg-core'
import { relations } from 'drizzle-orm'

// Players Table
export const players = pgTable(
  'players',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    starboundId: text('starbound_id').unique().notNull(),
    displayName: text('display_name').notNull(),
    currency: bigint('currency', { mode: 'number' }).default(1000).notNull(),
    factionId: uuid('faction_id').references(() => factions.id),
    reputation: integer('reputation').default(0).notNull(),
    isBanned: boolean('is_banned').default(false).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [index('idx_players_starbound_id').on(table.starboundId)]
)

export const playersRelations = relations(players, ({ one, many }) => ({
  faction: one(factions, {
    fields: [players.factionId],
    references: [factions.id],
  }),
  factionMembership: one(factionMembers, {
    fields: [players.id],
    references: [factionMembers.playerId],
  }),
  listings: many(marketListings),
  transactions: many(transactions),
}))

// Factions Table
export const factions = pgTable('factions', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').unique().notNull(),
  tag: text('tag').unique().notNull(),
  leaderId: uuid('leader_id'),
  motd: text('motd'),
  bankCurrency: bigint('bank_currency', { mode: 'number' }).default(0).notNull(),
  homeWorldCoords: text('home_world_coords'),
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
})

export const factionsRelations = relations(factions, ({ one, many }) => ({
  leader: one(players, {
    fields: [factions.leaderId],
    references: [players.id],
  }),
  members: many(factionMembers),
}))

// Faction Members Junction Table
export const factionMembers = pgTable(
  'faction_members',
  {
    factionId: uuid('faction_id')
      .references(() => factions.id, { onDelete: 'cascade' })
      .notNull(),
    playerId: uuid('player_id')
      .references(() => players.id, { onDelete: 'cascade' })
      .notNull(),
    role: text('role').default('member').notNull(), // 'leader', 'officer', 'member'
    joinedAt: timestamp('joined_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [primaryKey({ columns: [table.factionId, table.playerId] })]
)

export const factionMembersRelations = relations(factionMembers, ({ one }) => ({
  faction: one(factions, {
    fields: [factionMembers.factionId],
    references: [factions.id],
  }),
  player: one(players, {
    fields: [factionMembers.playerId],
    references: [players.id],
  }),
}))

// Market Listings Table
export const marketListings = pgTable(
  'market_listings',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    sellerId: uuid('seller_id')
      .references(() => players.id)
      .notNull(),
    itemName: text('item_name').notNull(),
    itemCount: integer('item_count').notNull(),
    itemParams: jsonb('item_params').default({}).notNull(),
    pricePerUnit: integer('price_per_unit').notNull(),
    totalPrice: integer('total_price').notNull(),
    status: text('status').default('active').notNull(), // 'active', 'sold', 'cancelled', 'expired'
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  },
  (table) => [
    index('idx_listings_status').on(table.status),
    index('idx_listings_seller').on(table.sellerId),
  ]
)

export const marketListingsRelations = relations(marketListings, ({ one }) => ({
  seller: one(players, {
    fields: [marketListings.sellerId],
    references: [players.id],
  }),
}))

// Transactions Table (Audit Log)
export const transactions = pgTable(
  'transactions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    type: text('type').notNull(), // 'market_purchase', 'market_sale', etc.
    playerId: uuid('player_id')
      .references(() => players.id)
      .notNull(),
    amount: bigint('amount', { mode: 'number' }).notNull(),
    metadata: jsonb('metadata').default({}).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => [index('idx_transactions_player').on(table.playerId)]
)

export const transactionsRelations = relations(transactions, ({ one }) => ({
  player: one(players, {
    fields: [transactions.playerId],
    references: [players.id],
  }),
}))

// Zones Table
export const zones = pgTable('zones', {
  id: text('id').primaryKey(),
  worldCoords: text('world_coords').notNull(),
  zoneType: text('zone_type').notNull(), // 'hub', 'wild', 'faction', 'event'
  pvpEnabled: boolean('pvp_enabled').default(false).notNull(),
  buildingAllowed: boolean('building_allowed').default(true).notNull(),
  resetSchedule: text('reset_schedule'), // 'weekly', 'monthly', null
  lastResetAt: timestamp('last_reset_at', { withTimezone: true }),
})

// Pending Items Table (for mailbox-style item delivery)
export const pendingItems = pgTable('pending_items', {
  id: uuid('id').primaryKey().defaultRandom(),
  playerId: uuid('player_id')
    .references(() => players.id, { onDelete: 'cascade' })
    .notNull(),
  itemName: text('item_name').notNull(),
  itemCount: integer('item_count').notNull(),
  itemParams: jsonb('item_params').default({}).notNull(),
  source: text('source').notNull(), // 'market_purchase', 'market_return', 'event_reward'
  createdAt: timestamp('created_at', { withTimezone: true }).defaultNow().notNull(),
})

export const pendingItemsRelations = relations(pendingItems, ({ one }) => ({
  player: one(players, {
    fields: [pendingItems.playerId],
    references: [players.id],
  }),
}))

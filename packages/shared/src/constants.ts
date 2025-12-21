// Currency Configuration
export const CURRENCY_NAME = 'Credits'
export const CURRENCY_SYMBOL = 'CR'
export const STARTING_CURRENCY = 1000
export const LISTING_FEE_PERCENT = 5
export const LISTING_DURATION_DAYS = 7
export const MAX_LISTINGS_PER_PLAYER = 20

// Faction Configuration
export const FACTION_CREATION_COST = 5000
export const FACTION_TAG_MIN_LENGTH = 2
export const FACTION_TAG_MAX_LENGTH = 5
export const FACTION_NAME_MIN_LENGTH = 3
export const FACTION_NAME_MAX_LENGTH = 32

// Zone Types
export const ZONE_TYPES = ['hub', 'wild', 'faction', 'event'] as const
export type ZoneType = (typeof ZONE_TYPES)[number]

// Command Types (Lua -> Bridge)
export const COMMAND_TYPES = [
  'player_join',
  'player_leave',
  'market_create',
  'market_purchase',
  'market_cancel',
  'claim_item',
  'faction_create',
  'faction_join',
  'faction_leave',
  'faction_invite',
  'faction_kick',
  'faction_deposit',
] as const
export type CommandType = (typeof COMMAND_TYPES)[number]

// Transaction Types
export const TRANSACTION_TYPES = [
  'market_purchase',
  'market_sale',
  'market_listing_fee',
  'faction_deposit',
  'faction_withdrawal',
  'event_reward',
  'admin_adjustment',
] as const
export type TransactionType = (typeof TRANSACTION_TYPES)[number]

// Faction Roles
export const FACTION_ROLES = ['leader', 'officer', 'member'] as const
export type FactionRole = (typeof FACTION_ROLES)[number]

// Market Listing Status
export const LISTING_STATUSES = ['active', 'sold', 'cancelled', 'expired'] as const
export type ListingStatus = (typeof LISTING_STATUSES)[number]

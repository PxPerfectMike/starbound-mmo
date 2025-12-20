import type { ZoneType, FactionRole, ListingStatus, TransactionType, CommandType } from './constants'

// Player Types
export interface Player {
  id: string
  starboundId: string
  displayName: string
  currency: number
  factionId: string | null
  reputation: number
  isBanned: boolean
  createdAt: Date
  lastSeenAt: Date
}

export interface PlayerState {
  id: string
  displayName: string
  currency: number
  factionId: string | null
  factionTag: string | null
  pendingItems: PendingItem[]
  notifications: Notification[]
}

export interface PendingItem {
  id: string
  itemName: string
  itemCount: number
  itemParams: Record<string, unknown>
  source: 'market_purchase' | 'market_return' | 'event_reward'
  createdAt: string
}

export interface Notification {
  id: string
  message: string
  type: 'info' | 'success' | 'warning' | 'error'
  createdAt: string
}

// Faction Types
export interface Faction {
  id: string
  name: string
  tag: string
  leaderId: string
  motd: string | null
  bankCurrency: number
  homeWorldCoords: string | null
  createdAt: Date
}

export interface FactionMember {
  factionId: string
  playerId: string
  role: FactionRole
  joinedAt: Date
}

export interface FactionWithMembers extends Faction {
  members: (FactionMember & { player: Pick<Player, 'id' | 'displayName'> })[]
}

// Market Types
export interface ItemDescriptor {
  name: string
  count: number
  parameters: Record<string, unknown>
}

export interface MarketListing {
  id: string
  sellerId: string
  itemName: string
  itemCount: number
  itemParams: Record<string, unknown>
  pricePerUnit: number
  totalPrice: number
  status: ListingStatus
  createdAt: Date
  expiresAt: Date
}

export interface MarketListingWithSeller extends MarketListing {
  seller: Pick<Player, 'id' | 'displayName'>
}

// Transaction Types
export interface Transaction {
  id: string
  type: TransactionType
  playerId: string
  amount: number
  metadata: Record<string, unknown>
  createdAt: Date
}

// Zone Types
export interface Zone {
  id: string
  worldCoords: string
  zoneType: ZoneType
  pvpEnabled: boolean
  buildingAllowed: boolean
  resetSchedule: string | null
  lastResetAt: Date | null
}

// Command Types (from Lua bridge)
export interface BridgeCommand<T extends CommandType = CommandType> {
  id: string
  type: T
  playerId: string
  timestamp: number
  data: CommandData[T]
}

export interface CommandData {
  player_join: {
    starboundId: string
    displayName: string
  }
  player_leave: Record<string, never>
  market_create: {
    item: ItemDescriptor
    pricePerUnit: number
  }
  market_purchase: {
    listingId: string
  }
  market_cancel: {
    listingId: string
  }
  faction_create: {
    name: string
    tag: string
  }
  faction_join: {
    factionId: string
  }
  faction_leave: Record<string, never>
  faction_invite: {
    targetPlayerId: string
  }
  faction_kick: {
    targetPlayerId: string
  }
  faction_deposit: {
    amount: number
  }
}

// PartyKit Message Types
export interface PartyKitMessage {
  type: string
  [key: string]: unknown
}

export interface MarketSyncMessage extends PartyKitMessage {
  type: 'sync'
  listings: MarketListingWithSeller[]
}

export interface MarketUpdateMessage extends PartyKitMessage {
  type: 'listing_added' | 'listing_removed' | 'listing_sold'
  listing: MarketListingWithSeller
}

export interface PresenceUpdateMessage extends PartyKitMessage {
  type: 'presence_update'
  onlinePlayers: { playerId: string; zone: string; lastSeen: string }[]
}

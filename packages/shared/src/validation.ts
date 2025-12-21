import { z } from 'zod'
import {
  COMMAND_TYPES,
  FACTION_NAME_MAX_LENGTH,
  FACTION_NAME_MIN_LENGTH,
  FACTION_TAG_MAX_LENGTH,
  FACTION_TAG_MIN_LENGTH,
} from './constants'

// Item Descriptor Schema
export const itemDescriptorSchema = z.object({
  name: z.string().min(1),
  count: z.number().int().positive(),
  parameters: z.record(z.unknown()).default({}),
})

// Command Schemas
export const playerJoinDataSchema = z.object({
  starboundId: z.string().min(1),
  displayName: z.string().min(1).max(32),
})

export const playerLeaveDataSchema = z.object({})

export const marketCreateDataSchema = z.object({
  item: itemDescriptorSchema,
  pricePerUnit: z.number().int().positive(),
})

export const marketPurchaseDataSchema = z.object({
  listingId: z.string().uuid(),
})

export const marketCancelDataSchema = z.object({
  listingId: z.string().uuid(),
})

export const claimItemDataSchema = z.object({
  pendingItemId: z.string().uuid(),
})

export const factionCreateDataSchema = z.object({
  name: z
    .string()
    .min(FACTION_NAME_MIN_LENGTH)
    .max(FACTION_NAME_MAX_LENGTH)
    .regex(/^[a-zA-Z0-9\s]+$/, 'Faction name must be alphanumeric'),
  tag: z
    .string()
    .min(FACTION_TAG_MIN_LENGTH)
    .max(FACTION_TAG_MAX_LENGTH)
    .regex(/^[A-Z0-9]+$/, 'Faction tag must be uppercase alphanumeric'),
})

export const factionJoinDataSchema = z.object({
  factionId: z.string().uuid(),
})

export const factionLeaveDataSchema = z.object({})

export const factionInviteDataSchema = z.object({
  targetPlayerId: z.string().uuid(),
})

export const factionKickDataSchema = z.object({
  targetPlayerId: z.string().uuid(),
})

export const factionDepositDataSchema = z.object({
  amount: z.number().int().positive(),
})

// Command Data Schema Map
export const commandDataSchemas = {
  player_join: playerJoinDataSchema,
  player_leave: playerLeaveDataSchema,
  market_create: marketCreateDataSchema,
  market_purchase: marketPurchaseDataSchema,
  market_cancel: marketCancelDataSchema,
  claim_item: claimItemDataSchema,
  faction_create: factionCreateDataSchema,
  faction_join: factionJoinDataSchema,
  faction_leave: factionLeaveDataSchema,
  faction_invite: factionInviteDataSchema,
  faction_kick: factionKickDataSchema,
  faction_deposit: factionDepositDataSchema,
} as const

// Bridge Command Schema
export const bridgeCommandSchema = z.object({
  id: z.string().min(1),
  type: z.enum(COMMAND_TYPES),
  playerId: z.string().min(1),
  timestamp: z.number().int().positive(),
  data: z.unknown(),
})

// Validate command with proper data schema
export function validateCommand(command: unknown) {
  const baseResult = bridgeCommandSchema.safeParse(command)
  if (!baseResult.success) {
    return { success: false as const, error: baseResult.error }
  }

  const { type, data } = baseResult.data
  const dataSchema = commandDataSchemas[type]
  const dataResult = dataSchema.safeParse(data)

  if (!dataResult.success) {
    return { success: false as const, error: dataResult.error }
  }

  return {
    success: true as const,
    data: { ...baseResult.data, data: dataResult.data },
  }
}

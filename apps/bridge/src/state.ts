import { writeFile, mkdir } from 'fs/promises'
import { join, dirname } from 'path'
import type { PlayerState, PendingItem, Notification } from '@starbound-mmo/shared'

export interface StateWriter {
  writePlayerState(playerId: string, state: Partial<PlayerState>): Promise<void>
  addPlayerNotification(playerId: string, notification: Notification): Promise<void>
  addPlayerPendingItem(playerId: string, item: PendingItem): Promise<void>
  writeMarketCache(listings: unknown[]): Promise<void>
}

export function createStateWriter(bridgeDir: string): StateWriter {
  const stateDir = join(bridgeDir, 'state')
  const cacheDir = join(bridgeDir, 'cache')

  // In-memory state cache to avoid excessive file reads
  const playerStates = new Map<string, PlayerState>()

  async function ensureDir(dir: string) {
    await mkdir(dirname(dir), { recursive: true })
  }

  async function writePlayerState(playerId: string, updates: Partial<PlayerState>): Promise<void> {
    // Get or create player state
    let state = playerStates.get(playerId)
    if (!state) {
      state = {
        id: playerId,
        displayName: '',
        currency: 0,
        factionId: null,
        factionTag: null,
        pendingItems: [],
        notifications: [],
      }
    }

    // Apply updates
    state = { ...state, ...updates }
    playerStates.set(playerId, state)

    // Write to file
    const filePath = join(stateDir, `player_${playerId}.json`)
    await ensureDir(filePath)
    await writeFile(filePath, JSON.stringify(state, null, 2))
    console.log(`Updated state for player ${playerId}`)
  }

  async function addPlayerNotification(playerId: string, notification: Notification): Promise<void> {
    let state = playerStates.get(playerId)
    if (!state) {
      state = {
        id: playerId,
        displayName: '',
        currency: 0,
        factionId: null,
        factionTag: null,
        pendingItems: [],
        notifications: [],
      }
    }

    // Add notification (keep last 20)
    state.notifications = [notification, ...state.notifications].slice(0, 20)
    playerStates.set(playerId, state)

    const filePath = join(stateDir, `player_${playerId}.json`)
    await ensureDir(filePath)
    await writeFile(filePath, JSON.stringify(state, null, 2))
  }

  async function addPlayerPendingItem(playerId: string, item: PendingItem): Promise<void> {
    let state = playerStates.get(playerId)
    if (!state) {
      state = {
        id: playerId,
        displayName: '',
        currency: 0,
        factionId: null,
        factionTag: null,
        pendingItems: [],
        notifications: [],
      }
    }

    state.pendingItems.push(item)
    playerStates.set(playerId, state)

    const filePath = join(stateDir, `player_${playerId}.json`)
    await ensureDir(filePath)
    await writeFile(filePath, JSON.stringify(state, null, 2))
  }

  async function writeMarketCache(listings: unknown[]): Promise<void> {
    const filePath = join(cacheDir, 'market_listings.json')
    await ensureDir(filePath)
    await writeFile(
      filePath,
      JSON.stringify(
        {
          updatedAt: new Date().toISOString(),
          listings,
        },
        null,
        2
      )
    )
  }

  return {
    writePlayerState,
    addPlayerNotification,
    addPlayerPendingItem,
    writeMarketCache,
  }
}

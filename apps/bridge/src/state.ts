import { writeFile, mkdir } from 'fs/promises'
import { join, dirname } from 'path'
import type { PlayerState, PendingItem, Notification } from '@starbound-mmo/shared'

export interface StateWriter {
  writePlayerState(playerId: string, starboundId: string, state: Partial<PlayerState>): Promise<void>
  addPlayerNotification(playerId: string, starboundId: string, notification: Notification): Promise<void>
  addPlayerPendingItem(playerId: string, starboundId: string, item: PendingItem): Promise<void>
  writeMarketCache(listings: unknown[]): Promise<void>
}

export function createStateWriter(bridgeDir: string, modDir?: string): StateWriter {
  const stateDir = join(bridgeDir, 'state')
  const cacheDir = join(bridgeDir, 'cache')
  // Also write to mod folder so Starbound can read via root.assetJson()
  const modCacheDir = modDir ? join(modDir, 'cache') : null

  // In-memory state cache to avoid excessive file reads
  const playerStates = new Map<string, PlayerState>()

  async function ensureDir(dir: string) {
    await mkdir(dirname(dir), { recursive: true })
  }

  async function writePlayerState(playerId: string, starboundId: string, updates: Partial<PlayerState>): Promise<void> {
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

    const stateJson = JSON.stringify(state, null, 2)

    // Write to bridge state directory
    const filePath = join(stateDir, `player_${playerId}.json`)
    await ensureDir(filePath)
    await writeFile(filePath, stateJson)

    // Also write to mod folder using starboundId so Lua can read it
    if (modCacheDir) {
      const modStatePath = join(modCacheDir, `player_${starboundId}.json`)
      await mkdir(modCacheDir, { recursive: true })
      await writeFile(modStatePath, stateJson)
      console.log(`Player state written for ${starboundId}`)
    }
  }

  async function addPlayerNotification(playerId: string, starboundId: string, notification: Notification): Promise<void> {
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

    const stateJson = JSON.stringify(state, null, 2)
    const filePath = join(stateDir, `player_${playerId}.json`)
    await ensureDir(filePath)
    await writeFile(filePath, stateJson)

    // Also write to mod folder
    if (modCacheDir) {
      const modStatePath = join(modCacheDir, `player_${starboundId}.json`)
      await mkdir(modCacheDir, { recursive: true })
      await writeFile(modStatePath, stateJson)
    }
  }

  async function addPlayerPendingItem(playerId: string, starboundId: string, item: PendingItem): Promise<void> {
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

    const stateJson = JSON.stringify(state, null, 2)
    const filePath = join(stateDir, `player_${playerId}.json`)
    await ensureDir(filePath)
    await writeFile(filePath, stateJson)

    // Also write to mod folder
    if (modCacheDir) {
      const modStatePath = join(modCacheDir, `player_${starboundId}.json`)
      await mkdir(modCacheDir, { recursive: true })
      await writeFile(modStatePath, stateJson)
    }
  }

  async function writeMarketCache(listings: unknown[]): Promise<void> {
    const cacheData = JSON.stringify(
      {
        updatedAt: new Date().toISOString(),
        listings,
      },
      null,
      2
    )

    // Write to bridge cache directory
    const filePath = join(cacheDir, 'market.json')
    await mkdir(cacheDir, { recursive: true })
    await writeFile(filePath, cacheData)

    // Also write to mod folder for Starbound asset access
    if (modCacheDir) {
      const modFilePath = join(modCacheDir, 'market.json')
      await mkdir(modCacheDir, { recursive: true })
      await writeFile(modFilePath, cacheData)
      console.log(`Market cache also written to mod folder: ${modFilePath}`)
    }
  }

  return {
    writePlayerState,
    addPlayerNotification,
    addPlayerPendingItem,
    writeMarketCache,
  }
}

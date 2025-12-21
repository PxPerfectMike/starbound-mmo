import 'dotenv/config'
import { mkdir } from 'fs/promises'
import { join } from 'path'
import { createWatcher } from './watcher.js'
import { createLogWatcher } from './logWatcher.js'
import { createPartyKitClient } from './partykit.js'
import { createCommandRouter } from './router.js'
import { createStateWriter } from './state.js'

const BRIDGE_DIR = process.env.BRIDGE_DIR || './mmo_bridge'
const PARTYKIT_HOST = process.env.PARTYKIT_HOST || 'localhost:1999'
// Path to Starbound mod folder - use game folder directly for live updates
const MOD_DIR = process.env.MOD_DIR || 'C:/Program Files (x86)/Steam/steamapps/common/Starbound/mods/starbound-mmo'
// Path to Starbound log for command relay (starbound.log for single-player, starbound_server.log for dedicated server)
const STARBOUND_LOG = process.env.STARBOUND_LOG || 'C:/Program Files (x86)/Steam/steamapps/common/Starbound/storage/starbound.log'

function getRequiredEnv(name: string): string {
  const value = process.env[name]
  if (!value) {
    console.error(`${name} environment variable is required`)
    process.exit(1)
  }
  return value
}

const DATABASE_URL = getRequiredEnv('DATABASE_URL')

async function ensureBridgeDirectories(bridgeDir: string) {
  const dirs = ['commands', 'state', 'cache']
  for (const dir of dirs) {
    await mkdir(join(bridgeDir, dir), { recursive: true })
  }
  console.log('Bridge directories ready')
}

async function main() {
  console.log('Starting Starbound MMO Bridge Service...')
  console.log(`Bridge directory: ${BRIDGE_DIR}`)
  console.log(`PartyKit host: ${PARTYKIT_HOST}`)
  console.log(`Starbound log: ${STARBOUND_LOG}`)

  // Ensure bridge directories exist
  await ensureBridgeDirectories(BRIDGE_DIR)

  // Initialize components
  const stateWriter = createStateWriter(BRIDGE_DIR, MOD_DIR)
  const partykit = createPartyKitClient(PARTYKIT_HOST)
  const router = createCommandRouter(DATABASE_URL, partykit, stateWriter)
  const watcher = createWatcher(BRIDGE_DIR, router)
  const logWatcher = createLogWatcher(STARBOUND_LOG, router)

  // Subscribe to market updates to write cache files
  partykit.onMarketMessage(async (data: unknown) => {
    const message = data as { type: string; listings?: unknown[] }

    if (message.type === 'sync' && message.listings) {
      // Initial sync - write all listings to cache
      await stateWriter.writeMarketCache(message.listings)
      console.log(`Market cache updated: ${message.listings.length} listings`)
    } else if (
      message.type === 'listing_added' ||
      message.type === 'listing_removed' ||
      message.type === 'listing_sold'
    ) {
      // Request fresh sync after any change
      partykit.sendToMarket({ type: 'refresh' })
    }
  })

  // Connect to PartyKit rooms
  await partykit.connect()

  // Start watching for commands (file-based and log-based)
  watcher.start()
  await logWatcher.start()

  console.log('Bridge service is running.')

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\nShutting down...')
    watcher.stop()
    logWatcher.stop()
    partykit.disconnect()
    process.exit(0)
  })

  process.on('SIGTERM', async () => {
    console.log('\nShutting down...')
    watcher.stop()
    logWatcher.stop()
    partykit.disconnect()
    process.exit(0)
  })
}

main().catch((err) => {
  console.error('Failed to start bridge service:', err)
  process.exit(1)
})

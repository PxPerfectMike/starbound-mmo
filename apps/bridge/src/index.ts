import 'dotenv/config'
import { createWatcher } from './watcher.js'
import { createPartyKitClient } from './partykit.js'
import { createCommandRouter } from './router.js'
import { createStateWriter } from './state.js'

const BRIDGE_DIR = process.env.BRIDGE_DIR || './mmo_bridge'
const PARTYKIT_HOST = process.env.PARTYKIT_HOST || 'localhost:1999'

function getRequiredEnv(name: string): string {
  const value = process.env[name]
  if (!value) {
    console.error(`${name} environment variable is required`)
    process.exit(1)
  }
  return value
}

const DATABASE_URL = getRequiredEnv('DATABASE_URL')

async function main() {
  console.log('Starting Starbound MMO Bridge Service...')
  console.log(`Bridge directory: ${BRIDGE_DIR}`)
  console.log(`PartyKit host: ${PARTYKIT_HOST}`)

  // Initialize components
  const stateWriter = createStateWriter(BRIDGE_DIR)
  const partykit = createPartyKitClient(PARTYKIT_HOST)
  const router = createCommandRouter(DATABASE_URL, partykit, stateWriter)
  const watcher = createWatcher(BRIDGE_DIR, router)

  // Connect to PartyKit rooms
  await partykit.connect()

  // Start watching for commands
  watcher.start()

  console.log('Bridge service is running.')

  // Handle graceful shutdown
  process.on('SIGINT', async () => {
    console.log('\nShutting down...')
    watcher.stop()
    partykit.disconnect()
    process.exit(0)
  })

  process.on('SIGTERM', async () => {
    console.log('\nShutting down...')
    watcher.stop()
    partykit.disconnect()
    process.exit(0)
  })
}

main().catch((err) => {
  console.error('Failed to start bridge service:', err)
  process.exit(1)
})

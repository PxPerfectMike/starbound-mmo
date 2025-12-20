import chokidar, { type FSWatcher } from 'chokidar'
import { readFile, unlink, mkdir } from 'fs/promises'
import { join } from 'path'
import { validateCommand, type CommandType } from '@starbound-mmo/shared'

export interface CommandRouter {
  handleCommand(command: {
    id: string
    type: CommandType
    playerId: string
    timestamp: number
    data: unknown
  }): Promise<void>
}

export function createWatcher(bridgeDir: string, router: CommandRouter) {
  const commandsDir = join(bridgeDir, 'commands')
  let watcher: FSWatcher | null = null

  async function ensureDirectories() {
    await mkdir(join(bridgeDir, 'commands'), { recursive: true })
    await mkdir(join(bridgeDir, 'state'), { recursive: true })
    await mkdir(join(bridgeDir, 'cache'), { recursive: true })
  }

  async function processCommandFile(filePath: string) {
    if (!filePath.endsWith('.json')) return

    try {
      const content = await readFile(filePath, 'utf-8')
      const rawCommand = JSON.parse(content)

      const result = validateCommand(rawCommand)
      if (!result.success) {
        console.error(`Invalid command in ${filePath}:`, result.error)
        // Move to error folder or delete
        await unlink(filePath).catch(() => {})
        return
      }

      const command = result.data
      console.log(`Processing command: ${command.type} from ${command.playerId}`)

      await router.handleCommand(command as {
        id: string
        type: CommandType
        playerId: string
        timestamp: number
        data: unknown
      })

      // Delete processed command file
      await unlink(filePath).catch(() => {})
      console.log(`Processed and removed: ${filePath}`)
    } catch (error) {
      console.error(`Error processing ${filePath}:`, error)
      // Optionally move to error folder
      await unlink(filePath).catch(() => {})
    }
  }

  function start() {
    ensureDirectories().then(() => {
      watcher = chokidar.watch(commandsDir, {
        persistent: true,
        ignoreInitial: false,
        awaitWriteFinish: {
          stabilityThreshold: 100,
          pollInterval: 50,
        },
      })

      watcher.on('add', (filePath: string) => {
        processCommandFile(filePath)
      })

      watcher.on('error', (error: Error) => {
        console.error('Watcher error:', error)
      })

      console.log(`Watching for commands in: ${commandsDir}`)
    })
  }

  function stop() {
    if (watcher) {
      watcher.close()
      watcher = null
    }
  }

  return { start, stop }
}

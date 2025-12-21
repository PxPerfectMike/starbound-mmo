import { open, stat } from 'fs/promises'
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

// Regex to match our command format: [MMO_CMD]{json}
const MMO_CMD_REGEX = /\[MMO_CMD\](.+)$/

export function createLogWatcher(logPath: string, router: CommandRouter) {
  let lastPosition = 0
  let intervalId: NodeJS.Timeout | null = null
  let isWatching = false
  const processedIds = new Set<string>()

  async function getFileSize(): Promise<number> {
    try {
      const stats = await stat(logPath)
      return stats.size
    } catch {
      return 0
    }
  }

  async function processNewLines() {
    if (!isWatching) return

    try {
      const currentSize = await getFileSize()

      // If file was truncated/rotated, reset position
      if (currentSize < lastPosition) {
        console.log('[LogWatcher] Log file rotated, resetting position')
        lastPosition = 0
      }

      // No new data
      if (currentSize <= lastPosition) return

      // Read new content
      const file = await open(logPath, 'r')
      try {
        const buffer = Buffer.alloc(currentSize - lastPosition)
        await file.read(buffer, 0, buffer.length, lastPosition)
        lastPosition = currentSize

        const newContent = buffer.toString('utf-8')
        const lines = newContent.split('\n')

        for (const line of lines) {
          await processLine(line.trim())
        }
      } finally {
        await file.close()
      }
    } catch (error) {
      // File might not exist yet, that's okay
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') {
        console.error('[LogWatcher] Error reading log:', error)
      }
    }
  }

  async function processLine(line: string) {
    const match = line.match(MMO_CMD_REGEX)
    if (!match) return

    const jsonStr = match[1]

    try {
      const rawCommand = JSON.parse(jsonStr)

      // Skip if we've already processed this command
      if (rawCommand.id && processedIds.has(rawCommand.id)) {
        return
      }

      const result = validateCommand(rawCommand)
      if (!result.success) {
        console.error('[LogWatcher] Invalid command:', result.error)
        return
      }

      const command = result.data
      console.log(`[LogWatcher] Processing command: ${command.type} from ${command.playerId}`)

      // Mark as processed
      if (command.id) {
        processedIds.add(command.id)
        // Keep set from growing too large
        if (processedIds.size > 1000) {
          const idsArray = Array.from(processedIds)
          for (let i = 0; i < 500; i++) {
            processedIds.delete(idsArray[i])
          }
        }
      }

      await router.handleCommand(command as {
        id: string
        type: CommandType
        playerId: string
        timestamp: number
        data: unknown
      })

      console.log(`[LogWatcher] Processed command: ${command.type}`)
    } catch (error) {
      console.error('[LogWatcher] Error processing command:', error)
    }
  }

  async function start() {
    if (isWatching) return

    isWatching = true

    // Start from end of file (don't process old commands)
    lastPosition = await getFileSize()
    console.log(`[LogWatcher] Watching log file: ${logPath}`)
    console.log(`[LogWatcher] Starting from position: ${lastPosition}`)

    // Poll every 500ms for new content
    intervalId = setInterval(() => {
      processNewLines().catch((err) => {
        console.error('[LogWatcher] Poll error:', err)
      })
    }, 500)
  }

  function stop() {
    isWatching = false
    if (intervalId) {
      clearInterval(intervalId)
      intervalId = null
    }
    console.log('[LogWatcher] Stopped')
  }

  return { start, stop }
}

import PartySocket from 'partysocket'

export interface PartyKitClient {
  connect(): Promise<void>
  disconnect(): void
  sendToMarket(message: object): void
  sendToPresence(message: object): void
  sendToFaction(factionId: string, message: object): void
  onMarketMessage(handler: (data: unknown) => void): void
}

export function createPartyKitClient(host: string): PartyKitClient {
  let marketSocket: PartySocket | null = null
  let presenceSocket: PartySocket | null = null
  const factionSockets = new Map<string, PartySocket>()
  const marketHandlers: ((data: unknown) => void)[] = []

  async function connect(): Promise<void> {
    return new Promise((resolve) => {
      // Connect to market room
      marketSocket = new PartySocket({
        host,
        room: 'market',
        party: 'market',
      })

      marketSocket.addEventListener('open', () => {
        console.log('Connected to Market room')
      })

      marketSocket.addEventListener('message', (event) => {
        try {
          const data = JSON.parse(event.data)
          console.log('[PartyKit] Market message received:', data.type, JSON.stringify(data).substring(0, 200))
          marketHandlers.forEach((handler) => handler(data))
        } catch (e) {
          console.error('Failed to parse market message:', e)
        }
      })

      marketSocket.addEventListener('error', (event) => {
        console.error('[PartyKit] Market socket error:', event)
      })

      // Connect to presence room
      presenceSocket = new PartySocket({
        host,
        room: 'global',
        party: 'presence',
      })

      presenceSocket.addEventListener('open', () => {
        console.log('Connected to Presence room')
        resolve()
      })

      presenceSocket.addEventListener('message', (event) => {
        try {
          const data = JSON.parse(event.data)
          // Handle presence updates - update player state files
          console.log('Presence update:', data.type)
        } catch (e) {
          console.error('Failed to parse presence message:', e)
        }
      })
    })
  }

  function disconnect() {
    marketSocket?.close()
    presenceSocket?.close()
    factionSockets.forEach((socket) => socket.close())
    factionSockets.clear()
  }

  function sendToMarket(message: object) {
    if (marketSocket?.readyState === WebSocket.OPEN) {
      console.log('[PartyKit] Sending to market:', JSON.stringify(message))
      marketSocket.send(JSON.stringify(message))
    } else {
      console.warn('[PartyKit] Market socket not open, cannot send:', message)
    }
  }

  function sendToPresence(message: object) {
    if (presenceSocket?.readyState === WebSocket.OPEN) {
      presenceSocket.send(JSON.stringify(message))
    }
  }

  function sendToFaction(factionId: string, message: object) {
    let socket = factionSockets.get(factionId)

    if (!socket || socket.readyState !== WebSocket.OPEN) {
      // Create connection to faction room
      socket = new PartySocket({
        host,
        room: factionId,
        party: 'faction',
      })

      socket.addEventListener('open', () => {
        console.log(`Connected to Faction room: ${factionId}`)
        socket!.send(JSON.stringify(message))
      })

      factionSockets.set(factionId, socket)
    } else {
      socket.send(JSON.stringify(message))
    }
  }

  function onMarketMessage(handler: (data: unknown) => void) {
    marketHandlers.push(handler)
  }

  return {
    connect,
    disconnect,
    sendToMarket,
    sendToPresence,
    sendToFaction,
    onMarketMessage,
  }
}

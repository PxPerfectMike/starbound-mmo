import PartySocket from 'partysocket'
import { writable, type Readable } from 'svelte/store'
import type { MarketListingWithSeller } from '@starbound-mmo/shared'

const PARTYKIT_HOST =
  import.meta.env.VITE_PARTYKIT_HOST ||
  (typeof window !== 'undefined' && window.location.hostname !== 'localhost'
    ? 'starbound-mmo.pxperfectmike.partykit.dev'
    : 'localhost:1999')

// Market connection
export function createMarketConnection() {
  const listings = writable<MarketListingWithSeller[]>([])
  const connected = writable(false)
  const error = writable<string | null>(null)

  let socket: PartySocket | null = null

  function connect() {
    socket = new PartySocket({
      host: PARTYKIT_HOST,
      room: 'market',
      party: 'market',
    })

    socket.addEventListener('open', () => {
      connected.set(true)
      error.set(null)
    })

    socket.addEventListener('close', () => {
      connected.set(false)
    })

    socket.addEventListener('error', (e) => {
      error.set('Connection error')
      console.error('PartyKit error:', e)
    })

    socket.addEventListener('message', (event) => {
      try {
        const data = JSON.parse(event.data)
        handleMessage(data)
      } catch (e) {
        console.error('Failed to parse message:', e)
      }
    })
  }

  function handleMessage(data: { type: string; [key: string]: unknown }) {
    switch (data.type) {
      case 'sync':
        listings.set(data.listings as MarketListingWithSeller[])
        break
      case 'listing_added':
        listings.update((current) => [data.listing as MarketListingWithSeller, ...current])
        break
      case 'listing_removed':
      case 'listing_sold':
        listings.update((current) =>
          current.filter((l) => l.id !== (data.listing as MarketListingWithSeller).id)
        )
        break
      case 'error':
        error.set(data.message as string)
        break
    }
  }

  function send(message: object) {
    if (socket?.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify(message))
    }
  }

  function disconnect() {
    socket?.close()
    socket = null
    connected.set(false)
  }

  function createListing(playerId: string, itemName: string, itemCount: number, pricePerUnit: number) {
    send({
      type: 'create_listing',
      playerId,
      itemName,
      itemCount,
      itemParams: {},
      pricePerUnit,
    })
  }

  function purchaseListing(playerId: string, listingId: string) {
    send({
      type: 'purchase',
      playerId,
      listingId,
    })
  }

  function cancelListing(playerId: string, listingId: string) {
    send({
      type: 'cancel',
      playerId,
      listingId,
    })
  }

  return {
    listings: listings as Readable<MarketListingWithSeller[]>,
    connected: connected as Readable<boolean>,
    error: error as Readable<string | null>,
    connect,
    disconnect,
    createListing,
    purchaseListing,
    cancelListing,
    refresh: () => send({ type: 'refresh' }),
  }
}

// Presence connection
export function createPresenceConnection() {
  const players = writable<{ playerId: string; displayName: string; zone: string }[]>([])
  const connected = writable(false)

  let socket: PartySocket | null = null

  function connect() {
    socket = new PartySocket({
      host: PARTYKIT_HOST,
      room: 'global',
      party: 'presence',
    })

    socket.addEventListener('open', () => {
      connected.set(true)
    })

    socket.addEventListener('close', () => {
      connected.set(false)
    })

    socket.addEventListener('message', (event) => {
      try {
        const data = JSON.parse(event.data)
        handleMessage(data)
      } catch (e) {
        console.error('Failed to parse message:', e)
      }
    })
  }

  function handleMessage(data: { type: string; [key: string]: unknown }) {
    switch (data.type) {
      case 'presence_sync':
        players.set(
          (data.onlinePlayers as { playerId: string; displayName: string; zone: string }[]) || []
        )
        break
      case 'player_online':
        players.update((current) => [
          ...current,
          {
            playerId: data.playerId as string,
            displayName: data.displayName as string,
            zone: data.zone as string,
          },
        ])
        break
      case 'player_offline':
        players.update((current) =>
          current.filter((p) => p.playerId !== (data.playerId as string))
        )
        break
      case 'zone_changed':
        players.update((current) =>
          current.map((p) =>
            p.playerId === data.playerId ? { ...p, zone: data.zone as string } : p
          )
        )
        break
    }
  }

  function disconnect() {
    socket?.close()
    socket = null
    connected.set(false)
  }

  return {
    players: players as Readable<{ playerId: string; displayName: string; zone: string }[]>,
    connected: connected as Readable<boolean>,
    connect,
    disconnect,
  }
}

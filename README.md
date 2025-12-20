# Starbound MMO

A persistent multiplayer layer for Starbound featuring a global market, factions, and shared exploration zones.

## Architecture

```
┌─────────────────────┐     ┌─────────────────────┐
│  Starbound Client   │     │   Web Browser       │
│  + MMO Mod          │     │   (SvelteKit)       │
└──────────┬──────────┘     └──────────┬──────────┘
           │                           │
           │ Starbound Protocol        │ HTTPS/WSS
           ▼                           ▼
┌──────────────────────┐    ┌─────────────────────────────┐
│  Starbound Server    │    │   Cloud Infrastructure     │
│  + MMO Mod           │    │   ├── SvelteKit (Vercel)   │
│  │                   │    │   ├── PartyKit (Cloudflare)│
│  └── Bridge Service  │───►│   └── Neon (PostgreSQL)   │
│      (Node.js)       │    │                            │
└──────────────────────┘    └─────────────────────────────┘
```

## Project Structure

```
starbound-mmo/
├── apps/
│   ├── web/          # SvelteKit web companion (Vercel)
│   └── bridge/       # Node.js file bridge service
├── packages/
│   ├── partykit/     # PartyKit real-time rooms
│   ├── shared/       # Shared types and validation
│   └── db/           # Drizzle ORM + Neon client
├── mod/              # Starbound mod (Lua + JSON)
└── server/           # Server configuration
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Web App | SvelteKit 2 |
| Real-Time | PartyKit (Cloudflare) |
| Database | Neon (PostgreSQL) |
| ORM | Drizzle |
| Bridge | Node.js + chokidar |
| Game Mod | Lua + JSON |
| Monorepo | pnpm + Turborepo |

## Setup

### Prerequisites

- Node.js 20+
- pnpm 9+
- Starbound (Steam)
- Neon database account
- Vercel account (optional, for deployment)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/starbound-mmo.git
   cd starbound-mmo
   ```

2. Install dependencies:
   ```bash
   pnpm install
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your Neon database URL and PartyKit host
   ```

4. Push database schema:
   ```bash
   pnpm db:push
   ```

5. Start development servers:
   ```bash
   pnpm dev
   ```

### Starbound Server Setup

1. Install Starbound dedicated server via Steam
2. Copy the `mod/` folder to the server's mods directory
3. Copy `server/starbound_server.config.example` and configure
4. Start the bridge service on the same machine:
   ```bash
   cd apps/bridge
   pnpm start
   ```
5. Start the Starbound server

### Client Setup

1. Copy the `mod/` folder to your local Starbound mods directory
2. Connect to the server

## Features

### MVP (Phase 1)

- [x] Monorepo setup
- [x] Database schema
- [x] PartyKit rooms (market, faction, presence)
- [x] Bridge service
- [x] Web companion (market browser)
- [x] Starbound mod shell

### Planned

- [ ] Hub station world
- [ ] In-game market terminal UI
- [ ] Faction system
- [ ] Wild zones
- [ ] Server events
- [ ] Admin tools

## Development

```bash
# Run all dev servers
pnpm dev

# Run specific app
pnpm --filter @starbound-mmo/web dev
pnpm --filter @starbound-mmo/bridge dev

# Build all
pnpm build

# Database operations
pnpm db:generate  # Generate migrations
pnpm db:push      # Push schema to database
pnpm db:studio    # Open Drizzle Studio
```

## License

MIT

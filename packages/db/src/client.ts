import { neon } from '@neondatabase/serverless'
import { drizzle } from 'drizzle-orm/neon-http'
import * as schema from './schema'

export function createClient(databaseUrl: string) {
  const sql = neon(databaseUrl)
  return drizzle(sql, { schema })
}

export type Database = ReturnType<typeof createClient>

// Re-export schema for convenience
export * from './schema'

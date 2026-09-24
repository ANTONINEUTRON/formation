import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';
import type { Database } from './db-types.js';

// pg returns numeric and bigint as strings by default; Formation stores
// points as numeric(10,1), and the app expects numbers.
pg.types.setTypeParser(1700, Number); // numeric
pg.types.setTypeParser(20, Number); // int8

/** Injection token for the Kysely connection. */
export const DB = 'DB_CONNECTION';

export type Db = Kysely<Database>;

/**
 * Connects to Postgres. The same code works against local Postgres and
 * Supabase's Postgres; Supabase connection strings carry `sslmode=require`.
 */
export function createDb(connectionString: string): Db {
  if (!connectionString) {
    throw new Error('DATABASE_URL is not configured');
  }
  const pool = new pg.Pool({
    connectionString,
    max: 10,
    ssl: connectionString.includes('sslmode=require')
      ? { rejectUnauthorized: false }
      : undefined,
  });
  return new Kysely<Database>({ dialect: new PostgresDialect({ pool }) });
}

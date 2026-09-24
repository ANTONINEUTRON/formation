/**
 * Applies `migrations/*.sql` in filename order, each in its own transaction,
 * recording what ran in `schema_migrations`. Safe to run repeatedly.
 *
 *   npm run db:migrate           # DATABASE_URL
 *   npm run db:migrate:test      # TEST_DATABASE_URL
 *   node dist/scripts/migrate.js --test --reset   # drop schema first
 */
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import pg from 'pg';

const MIGRATIONS_DIR = join(dirname(fileURLToPath(import.meta.url)), '../../migrations');

export interface MigrateOptions {
  /** Drops and recreates the public schema before applying migrations. */
  reset?: boolean;
  log?: (message: string) => void;
}

export async function migrate(
  connectionString: string,
  { reset = false, log = () => {} }: MigrateOptions = {},
): Promise<string[]> {
  const client = new pg.Client({
    connectionString,
    ssl: connectionString.includes('sslmode=require') ? { rejectUnauthorized: false } : undefined,
  });
  await client.connect();
  const applied: string[] = [];

  try {
    if (reset) {
      await client.query('drop schema public cascade; create schema public;');
      log('Reset public schema');
    }
    await client.query(
      'create table if not exists schema_migrations (name text primary key, applied_at timestamptz not null default now())',
    );
    const done = new Set(
      (await client.query<{ name: string }>('select name from schema_migrations')).rows.map(
        (r) => r.name,
      ),
    );

    for (const name of readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith('.sql')).sort()) {
      if (done.has(name)) continue;
      const sql = readFileSync(join(MIGRATIONS_DIR, name), 'utf8');
      await client.query('begin');
      try {
        await client.query(sql);
        await client.query('insert into schema_migrations (name) values ($1)', [name]);
        await client.query('commit');
      } catch (e) {
        await client.query('rollback');
        throw new Error(`Migration ${name} failed: ${String(e)}`);
      }
      applied.push(name);
      log(`Applied ${name}`);
    }
  } finally {
    await client.end();
  }
  return applied;
}

// CLI entry point.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    process.loadEnvFile();
  } catch {
    // No .env file; use the real environment.
  }
  const useTest = process.argv.includes('--test');
  const url = useTest ? process.env.TEST_DATABASE_URL : process.env.DATABASE_URL;
  if (!url) {
    console.error(`${useTest ? 'TEST_DATABASE_URL' : 'DATABASE_URL'} is required`);
    process.exit(1);
  }
  const applied = await migrate(url, {
    reset: process.argv.includes('--reset'),
    log: console.log,
  });
  console.log(applied.length === 0 ? 'Already up to date' : `Applied ${applied.length} migration(s)`);
}

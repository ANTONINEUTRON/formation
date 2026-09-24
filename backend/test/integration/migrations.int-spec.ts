import { sql } from 'kysely';
import { createDb } from '../../src/core/db.js';
import { migrate } from '../../src/scripts/migrate.js';

describe('migrations', () => {
  let url: string;

  beforeAll(() => {
    try {
      process.loadEnvFile();
    } catch {
      // No .env file; use the real environment.
    }
    url = process.env.TEST_DATABASE_URL ?? '';
    expect(url, 'TEST_DATABASE_URL is required').not.toBe('');
  });

  it('applies to an empty database and creates every table', async () => {
    await migrate(url, { reset: true });
    const db = createDb(url);
    try {
      const { rows } = await sql<{ table_name: string }>`
        select table_name from information_schema.tables where table_schema = 'public'
      `.execute(db);
      const tables = rows.map((r) => r.table_name);
      expect(tables).toEqual(
        expect.arrayContaining([
          'users',
          'xstocks',
          'rosters',
          'roster_slots',
          'price_ticks',
          'gameweeks',
          'score_entries',
          'classic_scores',
          'duels',
          'trophies',
          'schema_migrations',
        ]),
      );
    } finally {
      await db.destroy();
    }
  });

  it('is idempotent', async () => {
    expect(await migrate(url)).toEqual([]);
  });
});

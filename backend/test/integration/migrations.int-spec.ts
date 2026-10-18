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
      const tables = rows.map((r) => r.table_name).sort();
      expect(tables).toEqual([
        'asset_scoring_status',
        'assistant_avatars',
        'assistant_credits',
        'assistant_profiles',
        'assistant_usage',
        'badges',
        'classic_scores',
        'credit_ledger',
        'credit_purchases',
        'credit_quotes',
        'daily_substitutions',
        'device_tokens',
        'follows',
        'general_entries',
        'league_fixtures',
        'league_members',
        'leagues',
        'live_events',
        'market_depth',
        'match_weeks',
        'notifications',
        'points_ledger',
        'price_ticks',
        'push_log',
        'push_preferences',
        'roster_slots',
        'rosters',
        'schema_migrations',
        'score_entries',
        'scoring_anomalies',
        'season_results',
        'seasons',
        'skill_ratings',
        'users',
        'weekly_stats',
        'xstocks',
      ]);

      // 008 drops what gameweeks, duels and trophies left behind. An exact
      // match above already proves it, but naming them makes the failure
      // obvious if that migration is ever skipped.
      expect(tables).not.toContain('gameweeks');
      expect(tables).not.toContain('duels');
      expect(tables).not.toContain('trophies');
    } finally {
      await db.destroy();
    }
  });

  it('is idempotent', async () => {
    expect(await migrate(url)).toEqual([]);
  });
});

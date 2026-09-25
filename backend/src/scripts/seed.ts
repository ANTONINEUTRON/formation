/**
 * Seeds the hand-curated xStocks, and optionally demo leaderboard players.
 *
 * This is no longer the main way the catalogue is filled. The server populates
 * it from Jupiter at boot when the table is empty and refreshes it on a timer
 * (`XStocksCatalogueService`), which is what gets you the full ~100 xStocks.
 * This script remains useful for two reasons: it works with Jupiter
 * unreachable, and it is what establishes the hand-assigned risk tiers for the
 * original thirty, which the refresh then preserves rather than overwriting.
 *
 * Demo leaderboard players are NOT seeded by default. They are invented users
 * with invented point totals, and on a live deployment they sit on the ladder
 * looking like real competitors. Pass `--demo-players` to add them, which is
 * worth doing for a screenshot or a walkthrough and not otherwise.
 */
import { createHash } from 'node:crypto';
import bs58 from 'bs58';
import { createDb } from '../core/db.js';
import { SPORT_MODES } from '../domain/sport.js';
import { XSTOCKS_SEED } from '../xstocks/xstocks.seed.js';

const SEED_PLAYERS = [
  'diamondhands', 'tickertape', 'bullrunbrenda', 'thetaganger', 'nvda_maxi',
  'dividenddan', 'shortsqueeze', 'solstonks', 'bogleheadbob', 'yolo_yuki',
  'bluechipbea', 'gammaray', 'deepvalue', 'mooncalf', 'rebalancer',
  'candlewick', 'paperhandpat', 'etf_ella', 'momentummo', 'basisbp',
  'greenday', 'redcandle', 'bagholder', 'fomo_fin', 'tapereader',
  'hodlhannah', 'alphaseeker', 'betaboy', 'sharpe_ratio', 'drawdown',
];

try {
  process.loadEnvFile();
} catch {
  // No .env file; use the real environment.
}

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL is required');
  process.exit(1);
}
const db = createDb(url);

await db
  .insertInto('xstocks')
  .values(
    XSTOCKS_SEED.map((s) => ({
      mint: s.mint,
      symbol: s.symbol,
      company_name: s.companyName,
      tier: s.tier,
      decimals: 8,
    })),
  )
  .onConflict((oc) =>
    oc.column('mint').doUpdateSet((eb) => ({
      symbol: eb.ref('excluded.symbol'),
      company_name: eb.ref('excluded.company_name'),
      tier: eb.ref('excluded.tier'),
    })),
  )
  .execute();

if (!process.argv.includes('--demo-players')) {
  console.log(
    `Seeded ${XSTOCKS_SEED.length} xStocks. ` +
      'No demo players (pass --demo-players to add them).',
  );
  await db.destroy();
  process.exit(0);
}

// Deterministic, well-formed but keyless addresses so re-running is idempotent.
const digest = (text: string) => createHash('sha256').update(text).digest();

const users = await db
  .insertInto('users')
  .values(
    SEED_PLAYERS.map((name) => ({
      wallet_address: bs58.encode(digest(`formation-seed-${name}`)),
      username: name,
      is_seed: true,
    })),
  )
  .onConflict((oc) =>
    oc.column('wallet_address').doUpdateSet((eb) => ({ username: eb.ref('excluded.username') })),
  )
  .returning(['id', 'username'])
  .execute();

const scores = SPORT_MODES.flatMap((mode) =>
  users.map((user, i) => {
    const noise = digest(`${mode}-${user.username}`);
    return {
      user_id: user.id,
      sport_mode: mode,
      total_points: 420 - i * 11 + (noise[0] % 19),
      streak: noise[2] % 5,
    };
  }),
);

await db
  .insertInto('classic_scores')
  .values(scores)
  .onConflict((oc) =>
    oc.columns(['user_id', 'sport_mode']).doUpdateSet((eb) => ({
      total_points: eb.ref('excluded.total_points'),
      streak: eb.ref('excluded.streak'),
    })),
  )
  .execute();

console.log(
  `Seeded ${XSTOCKS_SEED.length} xStocks and ${users.length} DEMO players ` +
    `across ${SPORT_MODES.length} leagues.`,
);
await db.destroy();

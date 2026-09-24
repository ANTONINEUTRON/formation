/**
 * Seeds supported xStocks and demo leaderboard players.
 * Run with `npm run seed` after `npm run db:migrate`.
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
      last_gameweek_points: (noise[1] % 70) - 25,
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
      last_gameweek_points: eb.ref('excluded.last_gameweek_points'),
      streak: eb.ref('excluded.streak'),
    })),
  )
  .execute();

console.log(
  `Seeded ${XSTOCKS_SEED.length} xStocks and ${users.length} demo players across ${SPORT_MODES.length} leagues.`,
);
await db.destroy();

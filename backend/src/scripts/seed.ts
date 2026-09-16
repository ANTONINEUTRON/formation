/**
 * Seeds supported xStocks and demo leaderboard players.
 * Run with `npm run seed` after applying the migration in supabase/migrations.
 */
import { createClient } from '@supabase/supabase-js';
import bs58 from 'bs58';
import { createHash } from 'node:crypto';
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

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_KEY;
if (!url || !key) {
  console.error('SUPABASE_URL and SUPABASE_SERVICE_KEY are required');
  process.exit(1);
}
const db = createClient(url, key, { auth: { persistSession: false } });

function check(result: { error: { message: string } | null }, step: string) {
  if (result.error) throw new Error(`${step}: ${result.error.message}`);
}

check(
  await db.from('xstocks').upsert(
    XSTOCKS_SEED.map((s) => ({
      mint: s.mint,
      symbol: s.symbol,
      company_name: s.companyName,
      tier: s.tier,
      decimals: 8,
    })),
    { onConflict: 'mint' },
  ),
  'xstocks',
);

// Deterministic, well-formed but keyless addresses so re-running is idempotent.
const digest = (text: string) => createHash('sha256').update(text).digest();

const { data: users, error } = await db
  .from('users')
  .upsert(
    SEED_PLAYERS.map((name) => ({
      wallet_address: bs58.encode(digest(`formation-seed-${name}`)),
      username: name,
      is_seed: true,
    })),
    { onConflict: 'wallet_address' },
  )
  .select('id, username');
check({ error }, 'users');

const scores = SPORT_MODES.flatMap((mode) =>
  (users ?? []).map((user: { id: string; username: string }, i: number) => {
    const noise = digest(`${mode}-${user.username}`);
    return {
      user_id: user.id,
      sport_mode: mode,
      total_points: 600 - i * 19 + (noise[0] % 15) - ((noise[1] % 3) * 40 * (i % 4 === 0 ? 1 : 0)),
      streak: noise[2] % 5,
    };
  }),
);
check(await db.from('classic_scores').upsert(scores, { onConflict: 'user_id,sport_mode' }), 'classic_scores');

console.log(`Seeded ${XSTOCKS_SEED.length} xStocks and ${users?.length ?? 0} demo players across ${SPORT_MODES.length} leagues.`);

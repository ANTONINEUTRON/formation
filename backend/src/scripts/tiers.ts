/**
 * Previews the tier formula (domain/tiers.ts) against stored prices, and with
 * `--apply` saves it. The server also runs it by itself at each season start.
 *
 *   npm run tiers            # preview: what would change, and why
 *   npm run tiers -- --apply # save it
 *
 * Tiers marked 'manual' in xstocks.tier_source are never changed.
 */
import { loadConfig } from '../core/config.js';
import { createDb } from '../core/db.js';
import { TiersService } from '../xstocks/tiers.service.js';
import type { XStocksService } from '../xstocks/xstocks.service.js';

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
const apply = process.argv.includes('--apply');
const db = createDb(url);
// The running server caches the catalogue; it picks up new tiers within its cache lifetime.
const service = new TiersService(db, loadConfig(), { invalidate: () => {} } as unknown as XStocksService);

const now = Date.now();
const plan = apply ? await service.apply(now) : await service.plan(now);

const pct = (x: number | null) => (x === null ? '-' : `${Math.round(x * 100)}%`);
const rows = [...plan.decisions].sort(
  (a, b) => (a.risk ?? 101) - (b.risk ?? 101) || a.symbol.localeCompare(b.symbol),
);
console.log('symbol    risk  beta   vol   now       formula   next      why');
for (const d of rows) {
  console.log(
    [
      d.symbol.padEnd(9),
      String(d.risk ?? '-').padStart(4),
      String(d.beta ?? '-').padStart(5),
      pct(d.volatility).padStart(5),
      d.current.padEnd(9),
      (d.proposed ?? '-').padEnd(9),
      (d.next === d.current ? d.next : `${d.next} *`).padEnd(9),
      d.reason,
    ].join(' '),
  );
}

const changed = rows.filter((d) => d.next !== d.current).length;
console.log(`\n${changed} of ${rows.length} would change${apply ? ' (applied)' : ''}. * marks a change.`);
for (const s of plan.shortages) {
  console.log(`Warning: only ${s.listed} ${s.tier} stocks for ${s.mode}, whose lineups can need ${s.needed}.`);
}
if (!apply) console.log('Preview only. Run with --apply to save.');
await db.destroy();

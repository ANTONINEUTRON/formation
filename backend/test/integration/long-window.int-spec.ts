import { BENCHMARK_MINT, createHarness } from './harness.js';
import type { Harness } from './harness.js';
import { EntryScoringService } from '../../src/scoring/entry-scoring.service.js';
import { scoreEntry } from '../../src/scoring/engine/score-entry.js';
import type { LineupSnapshot, PriceBook, ScoreWindow } from '../../src/scoring/engine/types.js';

/**
 * Leagues longer than about a week are scored from a per-session summary of
 * the price history rather than every tick. This checks the summary scores
 * exactly as the full history does.
 */
describe('long-window scoring', () => {
  let h: Harness;

  beforeAll(async () => {
    h = await createHarness();
  });

  afterAll(async () => {
    await h.close();
  });

  it('scores a 10-day window from session summaries exactly as from every tick', async () => {
    await h.reset();
    const mints = [BENCHMARK_MINT, 'mint-NVDA', 'mint-TSLA', 'mint-KO'];
    const start = Date.UTC(2026, 0, 5, 12, 0, 0);
    const minutes = 10 * 24 * 60;

    // A deterministic random walk per mint, one tick a minute. The harness
    // uses ten-minute sessions, so each session holds ten ticks to summarise.
    let seed = 42;
    const random = () => {
      seed = (seed * 1_103_515_245 + 12_345) % 2 ** 31;
      return seed / 2 ** 31;
    };
    const rows: { mint: string; price_usd: number; captured_at: Date }[] = [];
    for (const mint of mints) {
      let price = 100;
      for (let m = 0; m <= minutes; m++) {
        price *= 1 + (random() - 0.5) * 0.01;
        rows.push({ mint, price_usd: price, captured_at: new Date(start + m * 60_000) });
      }
    }
    for (let i = 0; i < rows.length; i += 5_000) {
      await h.db.insertInto('price_ticks').values(rows.slice(i, i + 5_000)).execute();
    }

    const window: ScoreWindow = {
      start,
      end: start + minutes * 60_000,
      sessionMinutes: 10,
    };
    const first = (mint: string) => rows.find((r) => r.mint === mint)!.price_usd;
    const snapshot: LineupSnapshot = {
      mode: 'basketball',
      formation: null,
      captainSlot: 0,
      viceCaptainSlot: null,
      benchmarkPrice: first(BENCHMARK_MINT),
      slots: ['mint-NVDA', 'mint-TSLA', 'mint-KO'].map((mint, slotIndex) => ({
        slotIndex,
        role: ['PG', 'SG', 'SF'][slotIndex],
        mint,
        symbol: mint,
        startBalance: 10,
        startPrice: first(mint),
      })),
    };

    const full: PriceBook = new Map(mints.map((m) => [m, []]));
    for (const row of rows) full.get(row.mint)!.push({ at: row.captured_at.getTime(), price: row.price_usd });

    const summary = await h.app.get(EntryScoringService).priceBook(mints.slice(1), window);
    const summaryTicks = [...summary.values()].reduce((n, ticks) => n + ticks.length, 0);
    expect(summaryTicks).toBeLessThan(rows.length / 3);

    const input = {
      snapshot,
      endBalances: Object.fromEntries(snapshot.slots.map((s) => [s.mint, 10])),
      benchmarkMint: BENCHMARK_MINT,
      window,
    };
    expect(scoreEntry({ ...input, prices: summary })).toEqual(
      scoreEntry({ ...input, prices: full }),
    );
  });
});

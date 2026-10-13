import { guardSeries } from './guard.js';
import type { PriceTick } from './types.js';

const HOUR = 3_600_000;
const series = (...prices: number[]): PriceTick[] =>
  prices.map((price, i) => ({ at: (i + 1) * HOUR, price }));
const flat = (n: number, price = 100): PriceTick[] =>
  Array.from({ length: n + 1 }, (_, i) => ({ at: i * HOUR, price }));
const seed = { price: 100, benchmark: 100, pending: 0 as const };

describe('guardSeries', () => {
  it('passes ordinary moves through untouched', () => {
    const result = guardSeries(series(101, 99, 104), flat(3), seed);
    expect(result.ticks.map((t) => t.price)).toEqual([101, 99, 104]);
    expect(result.held).toBe(false);
    expect(result.jumps).toEqual([]);
  });

  it('holds a spike that reverts on the next tick, so it never banks', () => {
    const result = guardSeries(series(130, 100.5), flat(2), seed);
    // The spike is shown as tracking the benchmark (flat), then the real price.
    expect(result.ticks.map((t) => t.price)).toEqual([100, 100.5]);
    expect(result.jumps).toEqual([]);
  });

  it('banks a persistent 15% step clamped to 10%, then follows the real price', () => {
    const result = guardSeries(series(115, 115, 116.15), flat(3), seed);
    const prices = result.ticks.map((t) => Math.round(t.price * 100) / 100);
    expect(prices[0]).toBe(100); // held
    expect(prices[1]).toBe(110); // confirmed, clamped
    // +1% on the real price is +1% on the guarded one.
    expect(prices[2]).toBeCloseTo(111.1, 1);
    expect(result.jumps).toEqual([2 * HOUR]);
    expect(result.state).toMatchObject({ price: 116.15, pending: 0 });
  });

  it('measures moves relative to the benchmark', () => {
    // The market falls 12% and the stock with it: not a jump.
    const market: PriceTick[] = [
      { at: 0, price: 100 },
      { at: HOUR, price: 88 },
    ];
    const result = guardSeries(series(88), market, seed);
    expect(result.held).toBe(false);
    expect(result.ticks[0].price).toBe(88);
  });

  it('reports a held jump and its direction for the next tick to confirm', () => {
    const result = guardSeries(series(80), flat(1), seed);
    expect(result.held).toBe(true);
    expect(result.state).toEqual({ price: 100, benchmark: 100, pending: -1 });

    // The next tick, seeded with that state, confirms it.
    const next = guardSeries([{ at: 2 * HOUR, price: 80 }], flat(2), result.state);
    expect(next.jumps).toHaveLength(1);
    expect(next.ticks[0].price).toBeCloseTo(90);
  });

  it('a jump the other way restarts the wait rather than confirming', () => {
    const result = guardSeries(series(130, 70), flat(2), seed);
    expect(result.jumps).toEqual([]);
    expect(result.held).toBe(true);
    expect(result.state.pending).toBe(-1);
  });
});

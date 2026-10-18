import { assessAsset, ELIGIBILITY_HYSTERESIS_MS, nextStatus } from './eligibility.js';
import type { PriceTick } from './types.js';

const HOUR = 3_600_000;
const NOW = 24 * HOUR;

/** Hourly ticks over the last day, the benchmark wobbling every hour. */
const hours = Array.from({ length: 24 }, (_, i) => (i + 1) * HOUR);
const market: PriceTick[] = hours.map((at, i) => ({ at, price: 100 + (i % 2 === 0 ? 0.2 : -0.2) }));
const ticks = (price: (i: number) => number): PriceTick[] =>
  hours.map((at, i) => ({ at, price: price(i) }));

const assess = (series: PriceTick[], extra: Partial<Parameters<typeof assessAsset>[0]> = {}) =>
  assessAsset({
    ticks: series,
    benchmark: market,
    now: NOW,
    tickMinutes: 60,
    roundTripLossPct: 0.3,
    maxRoundTripLossPct: 2,
    ...extra,
  });

describe('assessAsset', () => {
  it('passes a liquid asset that trades with the market', () => {
    expect(assess(ticks((i) => 200 + Math.sin(i) * 2)).failure).toBeNull();
  });

  it("fails JNJx's real October pattern: frozen for hours, then stepping down", () => {
    // $428.67 unchanged for most of the day, then four steps to $251.36.
    const steps = [380.1, 335.4, 291.2, 251.36];
    const jnj = ticks((i) => (i < 18 ? 428.67 : (steps[i - 18] ?? 251.36)));
    const { failure, metrics } = assess(jnj);
    expect(failure).toBe('price_not_updating');
    expect(metrics.jumps).toBeGreaterThan(1);
    // When the market is also thin, that's the reason given: it's the cause.
    expect(assess(jnj, { roundTripLossPct: 24 }).failure).toBe('thin_market');
  });

  it('fails a price that steps around even while it updates', () => {
    const erratic = ticks((i) => (i % 6 === 5 ? 140 : 100) + i * 0.01);
    // Two persistent jumps (up and back down) each time.
    const stepped = ticks((i) => (Math.floor(i / 4) % 2 === 0 ? 100 : 125) + i * 0.01);
    expect(assess(stepped).failure).toBe('erratic_price');
    // A one-tick spike is held, not confirmed, so it isn't a jump.
    expect(assess(erratic).metrics.jumps).toBe(0);
  });

  it('fails a stale price, a missing one, and a thin market', () => {
    const fine = ticks((i) => 100 + i * 0.1);
    const old = fine.slice(0, 20);
    expect(assess(old).failure).toBe('stale_price');
    expect(assess([]).failure).toBe('no_price');
    // A round trip losing more than the limit, or with no route at all.
    expect(assess(fine, { roundTripLossPct: 2.5 }).failure).toBe('thin_market');
    expect(assess(fine, { roundTripLossPct: null }).failure).toBe('thin_market');
    expect(assess(fine, { roundTripLossPct: 2 }).failure).toBeNull();
    // Not measured yet doesn't count against an asset.
    expect(assess(fine, { roundTripLossPct: undefined }).failure).toBeNull();
  });

  it("can't judge updates while the market is shut, so it passes", () => {
    const shut = hours.map((at) => ({ at, price: 100 }));
    expect(assess(ticks(() => 50), { benchmark: shut }).failure).toBeNull();
  });
});

describe('nextStatus', () => {
  it('stops at once, and scores again only after a full day of passing', () => {
    const scoring = nextStatus(undefined, null, 0);
    expect(scoring.eligible).toBe(true);

    const broken = nextStatus(scoring, 'stale_price', HOUR);
    expect(broken).toMatchObject({ eligible: false, reason: 'stale_price', since: HOUR });

    const recovering = nextStatus(broken, null, 2 * HOUR);
    expect(recovering).toMatchObject({ eligible: false, reason: 'recovering', passingSince: 2 * HOUR });

    const stillWaiting = nextStatus(recovering, null, 2 * HOUR + ELIGIBILITY_HYSTERESIS_MS - 1);
    expect(stillWaiting.eligible).toBe(false);

    const back = nextStatus(stillWaiting, null, 2 * HOUR + ELIGIBILITY_HYSTERESIS_MS);
    expect(back).toMatchObject({ eligible: true, reason: null });
  });

  it('a failure while recovering restarts the wait', () => {
    const recovering = nextStatus(nextStatus(undefined, 'stale_price', 0), null, HOUR);
    const again = nextStatus(recovering, 'erratic_price', 2 * HOUR);
    expect(again).toMatchObject({ eligible: false, passingSince: null, since: 0 });
  });
});

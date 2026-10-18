import { describe, expect, it } from 'vitest';
import { fixedTier, measure, MIN_TRADING_DAYS, oneStep, planTiers, tiersByRisk } from './tiers.js';
import type { DailyClose, TierCandidate } from './tiers.js';

const DAY = 86_400_000;
// A Monday, so the first five days are weekdays.
const START = Date.UTC(2026, 6, 6);

/** Weekday closes following [returns], starting at 100. Weekends are skipped. */
function series(returns: number[]): DailyClose[] {
  const out: DailyClose[] = [];
  let price = 100;
  let day = START;
  out.push({ day, price });
  for (const r of returns) {
    do day += DAY; while ([0, 6].includes(new Date(day).getUTCDay()));
    price *= 1 + r;
    out.push({ day, price });
  }
  return out;
}

// A market that alternates up and down, and a few stocks that follow it.
const marketReturns = Array.from({ length: 60 }, (_, i) => (i % 2 === 0 ? 0.01 : -0.008));
const market = series(marketReturns);
const scaled = (k: number, noise = 0) =>
  series(marketReturns.map((r, i) => r * k + (i % 3 === 0 ? noise : -noise / 2)));

describe('measure', () => {
  it('reads beta 1 for the market against itself', () => {
    const m = measure(market, market)!;
    expect(m.beta).toBeCloseTo(1, 5);
    expect(m.days).toBe(60);
  });

  it('reads a stock moving twice the market as beta 2 and twice the volatility', () => {
    const m = measure(scaled(2), market)!;
    const base = measure(market, market)!;
    expect(m.beta).toBeCloseTo(2, 5);
    expect(m.volatility).toBeCloseTo(base.volatility * 2, 5);
  });

  it('refuses a short history', () => {
    const short = series(marketReturns.slice(0, MIN_TRADING_DAYS - 5));
    expect(measure(short, market)).toBeNull();
  });

  it('refuses a frozen price, which would otherwise look like the calmest stock', () => {
    const frozen = series(marketReturns.map((r, i) => (i % 4 === 0 ? r : 0)));
    expect(measure(frozen, market)).toBeNull();
  });
});

describe('tiersByRisk', () => {
  it('splits into thirds, calmest first', () => {
    const stocks = Array.from({ length: 9 }, (_, i) => ({ id: `s${i}`, beta: i * 0.3, volatility: 0.1 + i * 0.05 }));
    const tiers = tiersByRisk(stocks);
    expect([0, 1, 2].map((i) => tiers.get(`s${i}`)!.tier)).toEqual(['blue_chip', 'blue_chip', 'blue_chip']);
    expect([3, 4, 5].map((i) => tiers.get(`s${i}`)!.tier)).toEqual(['balanced', 'balanced', 'balanced']);
    expect([6, 7, 8].map((i) => tiers.get(`s${i}`)!.tier)).toEqual(['momentum', 'momentum', 'momentum']);
  });

  it('weighs beta and volatility equally', () => {
    // High beta but calm, and low beta but wild, land between the extremes.
    const tiers = tiersByRisk([
      { id: 'calm', beta: 0.2, volatility: 0.1 },
      { id: 'mixedA', beta: 2, volatility: 0.12 },
      { id: 'mixedB', beta: 0.3, volatility: 0.8 },
      { id: 'wild', beta: 2.5, volatility: 0.9 },
    ]);
    expect(tiers.get('calm')!.risk).toBe(0);
    expect(tiers.get('wild')!.risk).toBe(100);
    expect(tiers.get('mixedA')!.risk).toBe(50);
    expect(tiers.get('mixedB')!.risk).toBe(50);
  });
});

describe('fixedTier', () => {
  it('puts leveraged funds in momentum and T-bill funds in blue chip', () => {
    expect(fixedTier('TQQQx')).toBe('momentum');
    expect(fixedTier('XYZx', 'ProShares UltraPro QQQ')).toBe('momentum');
    expect(fixedTier('SGOVx')).toBe('blue_chip');
    expect(fixedTier('AAPLx', 'Apple')).toBeNull();
  });
});

describe('oneStep', () => {
  it('moves at most one tier', () => {
    expect(oneStep('blue_chip', 'momentum')).toBe('balanced');
    expect(oneStep('momentum', 'blue_chip')).toBe('balanced');
    expect(oneStep('balanced', 'momentum')).toBe('momentum');
    expect(oneStep('balanced', 'balanced')).toBe('balanced');
  });
});

describe('planTiers', () => {
  const candidate = (over: Partial<TierCandidate> & { symbol: string }): TierCandidate => ({
    mint: `mint-${over.symbol}`,
    companyName: over.symbol,
    tier: 'balanced',
    source: 'formula',
    closes: market,
    ...over,
  });

  it('keeps manual tiers, applies fixed ones, and holds stocks without history', () => {
    const decisions = planTiers(
      [
        candidate({ symbol: 'HANDx', tier: 'momentum', source: 'manual', closes: scaled(0.1, 0.001) }),
        candidate({ symbol: 'TQQQx', tier: 'blue_chip' }),
        candidate({ symbol: 'NEWx', tier: 'balanced', closes: market.slice(0, 10) }),
      ],
      market,
    );
    const by = new Map(decisions.map((d) => [d.symbol, d]));
    expect(by.get('HANDx')).toMatchObject({ reason: 'manual', next: 'momentum' });
    // Fixed tiers aren't limited to one step: a leveraged fund is never calm.
    expect(by.get('TQQQx')).toMatchObject({ reason: 'fixed', next: 'momentum' });
    expect(by.get('NEWx')).toMatchObject({ reason: 'not_enough_data', next: 'balanced', proposed: null });
  });

  it('moves a measured stock one step toward its third', () => {
    const decisions = planTiers(
      [
        candidate({ symbol: 'CALMx', tier: 'momentum', closes: scaled(0.2, 0.001) }),
        candidate({ symbol: 'MIDx', closes: scaled(1, 0.002) }),
        candidate({ symbol: 'WILDx', tier: 'blue_chip', closes: scaled(3, 0.01) }),
      ],
      market,
    );
    const by = new Map(decisions.map((d) => [d.symbol, d]));
    expect(by.get('CALMx')).toMatchObject({ proposed: 'blue_chip', next: 'balanced', reason: 'formula' });
    expect(by.get('MIDx')).toMatchObject({ proposed: 'balanced', next: 'balanced' });
    expect(by.get('WILDx')).toMatchObject({ proposed: 'momentum', next: 'balanced' });
  });
});

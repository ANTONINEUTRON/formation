import { scoreEntry, substitutionCost } from './score-entry.js';
import type { LineupSnapshot, PriceBook, ScoreInput, ScoreWindow } from './types.js';

const HOUR = 3_600_000;
const WEEK: ScoreWindow = { start: 0, end: 7 * 24 * HOUR, sessionMinutes: 24 * 60 };
const BENCHMARK = 'SPYx';

interface Pick {
  slotIndex: number;
  role: string;
  mint: string;
  endPrice: number;
  startBalance?: number;
  endBalance?: number;
}

function input(
  picks: Pick[],
  options: {
    mode?: LineupSnapshot['mode'];
    captainSlot?: number | null;
    viceCaptainSlot?: number | null;
    benchmarkEnd?: number;
    window?: ScoreWindow;
    extraTicks?: Record<string, [number, number][]>;
  } = {},
): ScoreInput {
  const window = options.window ?? WEEK;
  const prices: PriceBook = new Map([
    [BENCHMARK, [{ at: window.end, price: options.benchmarkEnd ?? 100 }]],
  ]);
  for (const pick of picks) {
    prices.set(pick.mint, [{ at: window.end, price: pick.endPrice }]);
  }
  for (const [mint, ticks] of Object.entries(options.extraTicks ?? {})) {
    prices.set(
      mint,
      ticks.map(([at, price]) => ({ at, price })),
    );
  }

  return {
    snapshot: {
      mode: options.mode ?? 'football',
      formation: '4-4-2',
      captainSlot: options.captainSlot ?? null,
      viceCaptainSlot: options.viceCaptainSlot ?? null,
      benchmarkPrice: 100,
      slots: picks.map((p) => ({
        slotIndex: p.slotIndex,
        role: p.role,
        mint: p.mint,
        symbol: p.mint,
        startBalance: p.startBalance ?? 1,
        startPrice: 100,
      })),
    },
    endBalances: Object.fromEntries(picks.map((p) => [p.mint, p.endBalance ?? 1])),
    prices,
    benchmarkMint: BENCHMARK,
    window,
  };
}

describe('scoreEntry', () => {
  it('matches the worked example in docs/formation-scoring.md §5.5', () => {
    // Market +1.0%; captain TSLAx +7.5% (FWD), JNJx -2.4% (DEF), KOx +0.4% (DEF).
    const result = scoreEntry(
      input(
        [
          { slotIndex: 9, role: 'FWD', mint: 'TSLAx', endPrice: 107.5 },
          { slotIndex: 1, role: 'DEF', mint: 'JNJx', endPrice: 97.6 },
          { slotIndex: 2, role: 'DEF', mint: 'KOx', endPrice: 100.4 },
        ],
        { captainSlot: 9, benchmarkEnd: 101 },
      ),
    );

    const total = (mint: string) => result.slots.find((s) => s.mint === mint)!.total;
    expect(total('TSLAx')).toBe(152); // (65 base + 8 goals + 3 assist) × 2
    expect(total('JNJx')).toBe(-35); // -34 base, 1 conceded
    expect(total('KOx')).toBe(-2); // -6 base, +4 clean sheet
    expect(result.total).toBe(115);
  });

  it('scores nothing for a pick not held for the whole window', () => {
    const result = scoreEntry(
      input([{ slotIndex: 9, role: 'FWD', mint: 'TSLAx', endPrice: 130, endBalance: 0 }]),
    );
    expect(result.slots[0]).toMatchObject({ counted: false, base: 0, total: 0, events: [] });
    expect(result.total).toBe(0);
  });

  it('gives the double to the vice-captain when the captain is sold', () => {
    const result = scoreEntry(
      input(
        [
          { slotIndex: 9, role: 'FWD', mint: 'TSLAx', endPrice: 130, endBalance: 0 },
          { slotIndex: 1, role: 'DEF', mint: 'KOx', endPrice: 102 },
        ],
        { captainSlot: 9, viceCaptainSlot: 1 },
      ),
    );
    const ko = result.slots.find((s) => s.mint === 'KOx')!;
    expect(ko.multiplier).toBe(2);
    expect(ko.total).toBe(54); // (20 base + 4 clean sheet + 3 assist) × 2
  });

  it('applies the basketball go-to scorer at 1.5 and team events', () => {
    const result = scoreEntry(
      input(
        [
          { slotIndex: 0, role: 'PG', mint: 'NVDAx', endPrice: 103 },
          { slotIndex: 1, role: 'SG', mint: 'METAx', endPrice: 102 },
        ],
        { mode: 'basketball', captainSlot: 0, window: { start: 0, end: 24 * HOUR, sessionMinutes: 24 * 60 } },
      ),
    );
    const pg = result.slots[0];
    expect(pg.multiplier).toBe(1.5);
    expect(pg.total).toBe(54); // (30 base + 6 buckets) × 1.5
    // Both picks beat a flat market by more than 1% in the only session.
    expect(result.teamEvents).toEqual([
      { code: 'double_double', label: 'Double-double', points: 5 },
    ]);
    expect(result.total).toBe(83);
  });

  it('has no captain in american football', () => {
    const result = scoreEntry(
      input([{ slotIndex: 0, role: 'QB', mint: 'AAPLx', endPrice: 104 }], {
        mode: 'american_football',
        captainSlot: 0,
      }),
    );
    expect(result.slots[0].multiplier).toBe(1);
    expect(result.slots[0].total).toBe(50); // 40 base + 6 touchdown + 4 clean pocket
  });

  it('scores an empty lineup as zero', () => {
    expect(scoreEntry(input([])).total).toBe(0);
  });

  it('scores a substituted pick up to its sale price, not to zero', () => {
    // Bought at 100, fell to 94 by mid-week, sold there, then rallied to 130.
    const sold = input(
      [{ slotIndex: 9, role: 'FWD', mint: 'TSLAx', endPrice: 130, endBalance: 0 }],
      { extraTicks: { TSLAx: [[0, 100], [3 * 24 * HOUR, 94], [WEEK.end, 130]] } },
    );
    const result = scoreEntry({
      ...sold,
      exits: { TSLAx: { at: 3 * 24 * HOUR, price: 94 } },
    });

    const slot = result.slots[0];
    expect(slot).toMatchObject({ counted: true, substituted: true });
    // -6% own return against a flat benchmark: the loss sticks, the later
    // rally does not, because it happened after the sale.
    expect(slot.ownReturn).toBeCloseTo(-0.06);
    expect(slot.base).toBe(-60);
  });

  it('charges only substitutions beyond the daily allowance', () => {
    expect(substitutionCost(0)).toBe(0);
    expect(substitutionCost(3)).toBe(0); // three are free every day
    expect(substitutionCost(5)).toBe(-8); // two paid at 4 points each
  });

  it('banks base alpha and role events on separate clocks', () => {
    const picks = [{ slotIndex: 9, role: 'FWD', mint: 'TSLAx', endPrice: 107.5 }];

    const baseOnly = scoreEntry({ ...input(picks), parts: { base: true, events: false } });
    expect(baseOnly.slots[0].events).toEqual([]);
    expect(baseOnly.slots[0].base).toBe(75);

    const eventsOnly = scoreEntry({ ...input(picks), parts: { base: false, events: true } });
    expect(eventsOnly.slots[0].base).toBe(0);
    // +7.5% against a flat benchmark: two 3% goals at 4 each, plus an assist
    // for clearing 1% of alpha.
    expect(eventsOnly.slots[0].total).toBe(11);
  });
});

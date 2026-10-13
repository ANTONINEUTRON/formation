import { SKILL_PRIOR_WEEKS, skillRating, weekForm, weekStats } from './skill.js';

describe('skillRating', () => {
  it('is 50 with no history: a manager who matches the market', () => {
    expect(skillRating([]).rating).toBe(50);
  });

  it('rewards steady market-beating over one lucky spike', () => {
    // Same total alpha over six weeks.
    const steady = skillRating([0.01, 0.012, 0.009, 0.011, 0.01, 0.008]);
    const lucky = skillRating([0.06, 0, 0, 0, 0, 0]);
    expect(steady.rating).toBeGreaterThan(lucky.rating);
    expect(steady.rating).toBeGreaterThan(80);
  });

  it('goes below 50 for a manager who lags the market', () => {
    expect(skillRating([-0.01, -0.02, -0.005]).rating).toBeLessThan(50);
  });

  it('shrinks a short history toward the middle', () => {
    const weeks = [0.01, 0.012, 0.011];
    const early = skillRating(weeks);
    const later = skillRating([...weeks, 0.01, 0.012, 0.011]);
    expect(SKILL_PRIOR_WEEKS).toBe(6);
    expect(early.rating).toBeLessThan(later.rating);
    expect(early.rating).toBeGreaterThan(50);
  });

  it('stays within 0–100', () => {
    expect(skillRating(Array.from({ length: 20 }, () => 0.5)).rating).toBeLessThanOrEqual(100);
    expect(skillRating(Array.from({ length: 20 }, () => -0.5)).rating).toBeGreaterThanOrEqual(0);
  });
});

describe('weekStats', () => {
  it("adds up a week's points, alpha, hit rate, goals and clean sheets", () => {
    const stats = weekStats([
      // TSLA captained at 2x: 40 shown, 20 of it is the stock's own.
      { kind: 'alpha', points: 30, detail: { slots: { TSLA: 40, KO: -10 }, captain: 'TSLA', multiplier: 2 } },
      { kind: 'alpha', points: 10, detail: { slots: { KO: 15, JPM: -5 }, captain: null } },
      {
        kind: 'events',
        points: 13,
        detail: {
          slots: [
            {
              events: [
                { code: 'goal', label: '2 goals', points: 8 },
                { code: 'clean_sheet', label: 'Clean sheet', points: 4 },
              ],
            },
            { events: [{ code: 'conceded', label: 'Conceded', points: -1 }] },
          ],
        },
      },
      { kind: 'substitution', points: -4, detail: null },
    ]);
    expect(stats).toMatchObject({
      points: 49,
      picks: 3,
      picksBeating: 2, // TSLA +20, KO +5; JPM -5
      goals: 2,
      cleanSheets: 1,
      captainPoints: 20,
      averagePickPoints: 6.7,
    });
    // (20 + 5 - 5) / 3 picks / 1000.
    expect(stats.alpha).toBeCloseTo(0.00667, 4);
  });

  it('is empty for a week with nothing banked', () => {
    expect(weekStats([])).toMatchObject({ points: 0, picks: 0, alpha: 0, captainPoints: null });
  });
});

describe('weekForm', () => {
  it('reads a week against the market', () => {
    expect(weekForm(12)).toBe('W');
    expect(weekForm(-3)).toBe('L');
    expect(weekForm(0.2)).toBe('D');
  });
});

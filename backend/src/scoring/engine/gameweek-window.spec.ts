import { gameweekWindow, nextGameweek } from './gameweek-window.js';

const HOUR = 3_600_000;
const anchor = Date.UTC(2026, 0, 5); // Monday

describe('gameweekWindow', () => {
  const weekly = { anchor, lengthMinutes: 7 * 24 * 60 };

  it('numbers windows from the anchor', () => {
    expect(gameweekWindow(anchor, weekly)).toEqual({
      number: 1,
      start: anchor,
      end: anchor + 7 * 24 * HOUR,
    });
    expect(gameweekWindow(anchor + 8 * 24 * HOUR, weekly).number).toBe(2);
  });

  it('keeps a moment inside its own window', () => {
    const w = gameweekWindow(anchor + 3 * 24 * HOUR, weekly);
    expect(w.start).toBeLessThanOrEqual(anchor + 3 * 24 * HOUR);
    expect(w.end).toBeGreaterThan(anchor + 3 * 24 * HOUR);
  });

  it('handles short demo windows', () => {
    const demo = { anchor, lengthMinutes: 60 };
    expect(gameweekWindow(anchor + 90 * 60_000, demo)).toEqual({
      number: 2,
      start: anchor + HOUR,
      end: anchor + 2 * HOUR,
    });
  });

  it('numbers windows before the anchor downwards', () => {
    expect(gameweekWindow(anchor - 1, weekly).number).toBe(0);
  });

  it('nextGameweek follows on immediately', () => {
    const first = gameweekWindow(anchor, weekly);
    const second = nextGameweek(first, weekly);
    expect(second.start).toBe(first.end);
    expect(second.number).toBe(first.number + 1);
  });
});

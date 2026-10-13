import { categoryOf, isQuiet, isValidTimeZone, localMinutes } from './push-rules.js';

describe('push rules', () => {
  it('puts every notification kind in a category players can switch off', () => {
    expect(categoryOf('goal')).toBe('goals');
    expect(categoryOf('match_week')).toBe('match_week');
    expect(categoryOf('not_scoring')).toBe('not_scoring');
    expect(categoryOf('season_final')).toBe('season');
    expect(categoryOf('league_settled')).toBe('leagues');
    expect(categoryOf('manager_move')).toBe('social');
  });

  it('handles quiet hours that wrap past midnight', () => {
    const [start, end] = [22 * 60, 8 * 60];
    expect(isQuiet(23 * 60, start, end)).toBe(true);
    expect(isQuiet(3 * 60, start, end)).toBe(true);
    expect(isQuiet(8 * 60, start, end)).toBe(false);
    expect(isQuiet(12 * 60, start, end)).toBe(false);
    // A daytime window works too, and an empty one is never quiet.
    expect(isQuiet(13 * 60, 12 * 60, 14 * 60)).toBe(true);
    expect(isQuiet(13 * 60, 600, 600)).toBe(false);
  });

  it("reads the local time in the player's zone", () => {
    const noonUtc = Date.UTC(2026, 9, 13, 12, 0);
    expect(localMinutes(noonUtc, 'UTC')).toBe(12 * 60);
    expect(localMinutes(noonUtc, 'Africa/Lagos')).toBe(13 * 60);
    expect(localMinutes(noonUtc, 'America/New_York')).toBe(8 * 60);
    // An unknown zone falls back to UTC rather than throwing.
    expect(localMinutes(noonUtc, 'Mars/Olympus')).toBe(12 * 60);
    expect(isValidTimeZone('Africa/Lagos')).toBe(true);
    expect(isValidTimeZone('Mars/Olympus')).toBe(false);
  });
});

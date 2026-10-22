import { dayBefore, isMilestone, liveStreak, localDay, nextStreak } from './visit-streak.js';

describe('visit streak', () => {
  it('counts days in the Manager’s own time zone', () => {
    // 23:30 UTC on 20 Oct is already 21 Oct in Lagos (UTC+1), still 20 Oct in New York.
    const at = Date.UTC(2026, 9, 20, 23, 30);
    expect(localDay(at, 'UTC')).toBe('2026-10-20');
    expect(localDay(at, 'Africa/Lagos')).toBe('2026-10-21');
    expect(localDay(at, 'America/New_York')).toBe('2026-10-20');
    expect(localDay(at, 'Not/AZone')).toBe('2026-10-20');
  });

  it('steps back a day across months and years', () => {
    expect(dayBefore('2026-11-01')).toBe('2026-10-31');
    expect(dayBefore('2027-01-01')).toBe('2026-12-31');
  });

  it('grows on consecutive days, holds on the same day, and restarts after a gap', () => {
    expect(nextStreak(null, 0, '2026-10-20')).toBe(1);
    expect(nextStreak('2026-10-19', 4, '2026-10-20')).toBe(5);
    expect(nextStreak('2026-10-20', 5, '2026-10-20')).toBe(5);
    expect(nextStreak('2026-10-17', 9, '2026-10-20')).toBe(1);
  });

  it('shows an unbroken streak until a whole day is missed', () => {
    expect(liveStreak('2026-10-20', 5, '2026-10-20')).toBe(5);
    expect(liveStreak('2026-10-19', 5, '2026-10-20')).toBe(5);
    expect(liveStreak('2026-10-18', 5, '2026-10-20')).toBe(0);
    expect(liveStreak(null, 0, '2026-10-20')).toBe(0);
  });

  it('marks milestones', () => {
    expect([1, 2, 3, 4, 7, 14, 30].filter(isMilestone)).toEqual([3, 7, 14, 30]);
  });
});

import { describe, expect, it } from 'vitest';
import { addUtcMonths, leagueEndsAt } from './leagues.service.js';

const HOUR = 3_600_000;

describe('addUtcMonths', () => {
  it('moves by calendar months', () => {
    expect(addUtcMonths(new Date('2026-10-09T12:00:00Z'), 11).toISOString()).toBe(
      '2027-09-09T12:00:00.000Z',
    );
  });

  it('clamps to the end of a shorter month', () => {
    expect(addUtcMonths(new Date('2026-03-31T08:00:00Z'), 11).toISOString()).toBe(
      '2027-02-28T08:00:00.000Z',
    );
  });
});

describe('leagueEndsAt', () => {
  const start = new Date('2026-10-09T12:00:00Z');

  it('keeps the old presets working', () => {
    for (const hours of [1, 6, 24, 72, 168]) {
      expect(leagueEndsAt(start, hours).getTime()).toBe(start.getTime() + hours * HOUR);
    }
  });

  it('allows any whole number of hours up to 11 months', () => {
    const cap = addUtcMonths(start, 11);
    const hours = (cap.getTime() - start.getTime()) / HOUR;
    expect(leagueEndsAt(start, hours)).toEqual(cap);
    expect(leagueEndsAt(start, 24 * 45).toISOString()).toBe('2026-11-23T12:00:00.000Z');
  });

  it('tolerates a daylight-saving hour past the cap, but no more', () => {
    const hours = (addUtcMonths(start, 11).getTime() - start.getTime()) / HOUR;
    expect(() => leagueEndsAt(start, hours + 1)).not.toThrow();
    expect(() => leagueEndsAt(start, hours + 2)).toThrow(/at most 11 months/);
  });

  it('rejects zero, negative and fractional durations', () => {
    expect(() => leagueEndsAt(start, 0)).toThrow();
    expect(() => leagueEndsAt(start, -5)).toThrow();
    expect(() => leagueEndsAt(start, 1.5)).toThrow();
  });
});

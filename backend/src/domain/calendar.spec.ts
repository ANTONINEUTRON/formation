import { GameCalendar, WEEKS_PER_SEASON } from './calendar.js';

const cal = new GameCalendar('2026-10-12');
const at = (iso: string) => new Date(iso).getTime();

describe('GameCalendar', () => {
  it('kicks off Monday 9:30am ET and reaches full time Friday 4pm ET', () => {
    const week = cal.week(1);
    // October is daylight time: ET = UTC-4.
    expect(week.kickOff.toISOString()).toBe('2026-10-12T13:30:00.000Z');
    expect(week.fullTime.toISOString()).toBe('2026-10-16T20:00:00.000Z');
    expect(week.nextKickOff.toISOString()).toBe('2026-10-19T13:30:00.000Z');
  });

  it('follows daylight saving: kick-off moves to 14:30 UTC in November', () => {
    // DST ends Sunday 1 November 2026.
    expect(cal.week(4).kickOff.toISOString()).toBe('2026-11-02T14:30:00.000Z');
    expect(cal.week(4).fullTime.toISOString()).toBe('2026-11-06T21:00:00.000Z');
  });

  it('places any moment in the week that most recently kicked off', () => {
    expect(cal.weekAt(at('2026-10-14T12:00:00Z')).number).toBe(1); // Wednesday
    expect(cal.weekAt(at('2026-10-18T12:00:00Z')).number).toBe(1); // Sunday
    expect(cal.weekAt(at('2026-10-19T13:00:00Z')).number).toBe(1); // Monday 9am ET
    expect(cal.weekAt(at('2026-10-19T13:30:00Z')).number).toBe(2); // kick-off
  });

  it('opens the transfer window from Friday full time to Monday kick-off', () => {
    expect(cal.inTransferWindow(at('2026-10-14T15:00:00Z'))).toBe(false);
    expect(cal.inTransferWindow(at('2026-10-16T19:59:00Z'))).toBe(false);
    expect(cal.inTransferWindow(at('2026-10-16T20:00:00Z'))).toBe(true);
    expect(cal.inTransferWindow(at('2026-10-18T12:00:00Z'))).toBe(true);
    expect(cal.inTransferWindow(at('2026-10-19T13:29:00Z'))).toBe(true);
    expect(cal.inTransferWindow(at('2026-10-19T13:30:00Z'))).toBe(false);
  });

  it('runs seasons of 12 match weeks', () => {
    const s1 = cal.season(1);
    expect(s1.startsAt.toISOString()).toBe('2026-10-12T13:30:00.000Z');
    expect(s1.endsAt).toEqual(cal.week(WEEKS_PER_SEASON + 1).kickOff);
    expect(cal.week(13)).toMatchObject({ season: 2, weekOfSeason: 1 });
    expect(cal.seasonAt(s1.endsAt).number).toBe(2);
    expect(cal.seasonAt(s1.endsAt.getTime() - 1).number).toBe(1);
  });

  it('snaps an anchor to its Monday', () => {
    expect(new GameCalendar('2026-10-14').week(1).kickOff).toEqual(cal.week(1).kickOff);
  });
});

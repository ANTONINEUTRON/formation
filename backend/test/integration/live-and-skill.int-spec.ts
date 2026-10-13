import { CALENDAR } from '../../src/domain/calendar.js';
import type { GameCalendar } from '../../src/domain/calendar.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { SkillService } from '../../src/scoring/skill.service.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

const TSLA = 'mint-TSLA';

/** SCORING_PLAN.md Phase 3: live events and skill. */
describe('live events and skill', () => {
  let h: Harness;
  let calendar: GameCalendar;
  let me: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
    calendar = h.app.get<GameCalendar>(CALENDAR);
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    me = await h.createPlayer('me');
  });

  const tickAfter = async (minutes: number) => {
    h.clock.advance(minutes);
    await h.priceTicks.tick();
  };
  const liveGoals = () =>
    h.db
      .selectFrom('live_events')
      .select(['mint', 'code', 'status', 'points'])
      .where('user_id', '=', me.id)
      .where('code', '=', 'goal')
      .execute();
  const goalNotices = async () =>
    (
      await h.db
        .selectFrom('notifications')
        .select('id')
        .where('user_id', '=', me.id)
        .where('kind', '=', 'goal')
        .execute()
    ).length;

  it('shows a goal live as provisional, then confirms it at the end of the day', async () => {
    await h.draft(me, 'football'); // TSLA up front
    // Sessions are ten minutes: open one, then move TSLA 5% inside it.
    await tickAfter(1);
    await tickAfter(10); // first tick of the next session: its baseline
    h.prices.move(TSLA, 1.05);
    await tickAfter(2);

    expect(await liveGoals()).toEqual([{ mint: TSLA, code: 'goal', status: 'provisional', points: 4 }]);
    expect(await goalNotices()).toBe(1);
    const roster = await h.rosters.getRoster(me, 'football');
    expect(roster.session!.liveEvents).toContainEqual(
      expect.objectContaining({ symbol: 'TSLAx', code: 'goal', status: 'provisional' }),
    );

    // Another tick in the same session: still one notice.
    await tickAfter(2);
    expect(await goalNotices()).toBe(1);

    await tickAfter(10); // the session closes and rolls up
    expect((await liveGoals())[0].status).toBe('confirmed');
    const banked = await h.db
      .selectFrom('points_ledger')
      .select('detail')
      .where('user_id', '=', me.id)
      .where('kind', '=', 'events')
      .execute();
    expect(JSON.stringify(banked)).toContain('"code":"goal"');
  });

  it('disallows a goal whose price falls back before the day ends', async () => {
    await h.draft(me, 'football');
    await tickAfter(1);
    await tickAfter(10);
    h.prices.move(TSLA, 1.05);
    await tickAfter(2);
    expect((await liveGoals())[0].status).toBe('provisional');

    h.prices.set(TSLA, 100);
    await tickAfter(2);
    expect((await liveGoals())[0].status).toBe('disallowed');

    await tickAfter(10);
    expect((await liveGoals())[0].status).toBe('disallowed');
  });

  it('works out weekly stats, a skill rating and the weekly badges at full time', async () => {
    const rival = await h.createPlayer('rival');
    const skill = h.app.get(SkillService);

    // Three weeks: I beat the market steadily; the rival has one big week.
    for (const n of [1, 2, 3]) {
      const week = calendar.week(n);
      const at = new Date(week.kickOff.getTime() + 86_400_000);
      const bank = (userId: string, slots: Record<string, number>, events: unknown = null) =>
        h.db
          .insertInto('points_ledger')
          .values([
            {
              user_id: userId,
              sport_mode: 'football',
              kind: 'alpha',
              points: Object.values(slots).reduce((s, p) => s + p, 0),
              detail: JSON.stringify({ slots, captain: TSLA, multiplier: 2 }),
              at,
              season: 1,
            },
            ...(events
              ? [
                  {
                    user_id: userId,
                    sport_mode: 'football' as const,
                    kind: 'events' as const,
                    points: 8,
                    detail: JSON.stringify(events),
                    at,
                    season: 1,
                  },
                ]
              : []),
          ])
          .execute();
      await bank(me.id, { [TSLA]: 30, 'mint-KO': 8 }, {
        slots: [{ events: [{ code: 'goal', label: '2 goals', points: 8 }] }],
      });
      await bank(rival.id, n === 1 ? { [TSLA]: 120, 'mint-KO': 60 } : { [TSLA]: -20, 'mint-KO': -10 });
      await skill.computeWeek(week, week.fullTime.getTime() + 60_000);
    }

    const stats = await h.db.selectFrom('weekly_stats').selectAll().where('user_id', '=', me.id).execute();
    expect(stats).toHaveLength(3);
    expect(stats[0]).toMatchObject({ picks: 2, picks_beating: 2, goals: 2, captain_points: 15 });

    const mine = await skill.skillFor(me.id, 'football');
    const theirs = await skill.skillFor(rival.id, 'football');
    expect(mine).toMatchObject({ weeks: 3, ranked: true, hitRatePct: 100, form: ['W', 'W', 'W'] });
    expect(mine!.rating).toBeGreaterThan(theirs!.rating);
    expect(theirs!.form).toEqual(['W', 'L', 'L']);

    const board = await h.league.leaderboard('football', me.id, { period: 'skill' });
    expect(board.map((e) => e.username)).toEqual(['me', 'rival']);
    expect(board[0].points).toBe(mine!.rating);

    const badges = await h.db
      .selectFrom('badges')
      .select(['user_id', 'code', 'week'])
      .where('code', '=', 'golden_boot')
      .execute();
    expect(badges).toHaveLength(3);
    expect(badges.every((b) => b.user_id === me.id)).toBe(true);
  });
});

import { CALENDAR } from '../../src/domain/calendar.js';
import type { GameCalendar } from '../../src/domain/calendar.js';
import type { AuthUser } from '../../src/domain/dto.js';
import type { SportMode } from '../../src/domain/sport.js';
import { MatchWeekService } from '../../src/scoring/match-week.service.js';
import { SeasonService } from '../../src/scoring/season.service.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

/** SCORING_PLAN.md Phase 2: seasons, match weeks and fixtures. */
describe('seasons and match weeks', () => {
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

  /** Writes a ledger row as if a tick had banked it. */
  const bank = async (
    userId: string,
    points: number,
    at: Date,
    kind: 'alpha' | 'events' = 'alpha',
    detail: unknown = null,
    mode: SportMode = 'football',
  ) => {
    await h.db
      .insertInto('points_ledger')
      .values({
        user_id: userId,
        sport_mode: mode,
        kind,
        points,
        detail: detail === null ? null : JSON.stringify(detail),
        at,
        season: calendar.weekAt(at).season,
      })
      .execute();
    await h.db
      .insertInto('classic_scores')
      .values({ user_id: userId, sport_mode: mode, total_points: points })
      .onConflict((oc) =>
        oc.columns(['user_id', 'sport_mode']).doUpdateSet((eb) => ({
          total_points: eb(eb.ref('classic_scores.total_points'), '+', points),
        })),
      )
      .execute();
  };

  const substitutionCharges = async () =>
    (
      await h.db
        .selectFrom('points_ledger')
        .select('points')
        .where('user_id', '=', me.id)
        .where('kind', '=', 'substitution')
        .execute()
    ).length;

  /** Swaps the GK back and forth [times] times: each swap is a substitution. */
  const swapKeeper = async (times: number) => {
    for (let i = 0; i < times; i++) {
      await h.rosters.fillSlot(me, 'football', 0, i % 2 === 0 ? 'mint-MSFT' : 'mint-AAPL');
    }
  };

  it('charges substitutions past the daily allowance during a match week', async () => {
    await h.draft(me, 'football'); // GK is AAPL
    await swapKeeper(5);
    expect(await substitutionCharges()).toBe(2);
  });

  it('makes substitutions free and unlimited in the weekend transfer window', async () => {
    await h.draft(me, 'football');
    h.clock.set(Date.UTC(2026, 0, 10, 15, 0, 0)); // Saturday
    await swapKeeper(6);
    expect(await substitutionCharges()).toBe(0);

    const roster = await h.rosters.getRoster(me, 'football');
    expect(roster.session!.transferWindowOpen).toBe(true);
    expect(roster.session!.matchWeek).toMatchObject({ number: 1, season: 1, weekOfSeason: 1 });
  });

  it('ranks the This week board by points since kick-off', async () => {
    const rival = await h.createPlayer('rival');
    const week = calendar.weekAt(h.clock.now());
    // The rival leads the season, but I'm ahead this week.
    await bank(rival.id, 500, new Date(week.kickOff.getTime() - 3_600_000));
    await bank(me.id, 40, new Date(h.clock.now() - 60_000));
    await bank(rival.id, 10, new Date(h.clock.now() - 60_000));

    const season = await h.league.leaderboard('football', me.id);
    expect(season.map((e) => e.username)).toEqual(['rival', 'me']);

    const thisWeek = await h.league.leaderboard('football', me.id, { period: 'match_week' });
    expect(thisWeek.map((e) => [e.username, e.points])).toEqual([
      ['me', 40],
      ['rival', 10],
    ]);
  });

  it('closes a season: freezes the table, awards badges, restarts from zero', async () => {
    const rival = await h.createPlayer('rival');
    await bank(me.id, 300, new Date(h.clock.now() - 60_000));
    await bank(rival.id, 120, new Date(h.clock.now() - 60_000));

    const seasonTwo = calendar.season(2).startsAt.getTime();
    await h.app.get(SeasonService).rollover(seasonTwo + 60_000);

    const results = await h.db.selectFrom('season_results').selectAll().orderBy('rank').execute();
    expect(results.map((r) => [r.user_id, r.rank, r.points])).toEqual([
      [me.id, 1, 300],
      [rival.id, 2, 120],
    ]);
    const badges = await h.db.selectFrom('badges').select(['user_id', 'code']).execute();
    expect(badges).toContainEqual({ user_id: me.id, code: 'season_champion' });
    expect(badges.some((b) => b.user_id === rival.id)).toBe(false);

    expect((await h.league.standing(me.id, 'football'))!.points).toBe(0);
    // Career points survive the reset.
    const career = await h.league.leaderboard('football', me.id, { period: 'all_time' });
    expect(career[0]).toMatchObject({ username: 'me', points: 300 });

    // Running it again changes nothing.
    await h.app.get(SeasonService).rollover(seasonTwo + 120_000);
    expect(await h.db.selectFrom('season_results').selectAll().execute()).toHaveLength(2);

    const profile = await h.app.get(SeasonService).history(me.id);
    expect(profile[0]).toMatchObject({ season: 1, rank: 1, players: 2 });
  });

  it('plays private leagues as weekly head-to-head fixtures with a table', async () => {
    const others = await Promise.all(['b', 'c', 'd'].map((n) => h.createPlayer(n)));
    const week2 = calendar.week(2);
    const week3 = calendar.week(3);
    const league = await h.leagues.create(me, {
      name: 'Office league',
      mode: 'football',
      visibility: 'private',
      startsAt: new Date(week2.kickOff.getTime() - 3_600_000),
      durationHours: Math.ceil((week3.fullTime.getTime() - week2.kickOff.getTime()) / 3_600_000) + 2,
      maxMembers: null,
    });
    for (const other of others) await h.leagues.join(other, { code: league.joinCode });

    h.clock.set(week2.kickOff.getTime() - 60_000);
    await h.leagues.processDue();
    const opened = await h.leagues.byId(me, league.id);
    // Weeks 2 and 3, two fixtures each.
    expect(opened.fixtures).toHaveLength(4);
    expect(new Set(opened.fixtures.map((f) => f.week))).toEqual(new Set([2, 3]));

    // Week 2 plays out: I score most.
    const during = new Date(week2.kickOff.getTime() + 86_400_000);
    await bank(me.id, 90, during);
    for (const [i, other] of others.entries()) await bank(other.id, 20 * i, during);

    await h.app.get(MatchWeekService).settleFixtures(week2.fullTime.getTime() + 60_000);
    const settled = await h.leagues.byId(me, league.id);
    const mine = settled.fixtures.find(
      (f) => f.week === 2 && (f.homeId === me.id || f.awayId === me.id),
    )!;
    expect(mine.status).toBe('final');
    expect(mine.homeId === me.id ? mine.homePoints : mine.awayPoints).toBe(90);

    expect(settled.table[0]).toMatchObject({ userId: me.id, won: 1, tablePoints: 3, form: ['W'] });
    expect(settled.table.reduce((sum, r) => sum + r.played, 0)).toBe(4);
  });

  it('builds the result card: score, man of the match, goals, turning point', async () => {
    const week = calendar.weekAt(h.clock.now());
    const t = (hours: number) => new Date(week.kickOff.getTime() + hours * 3_600_000);
    await bank(me.id, 12, t(1), 'alpha', { slots: { 'mint-TSLA': 15, 'mint-KO': -3 } });
    await bank(me.id, -30, t(2), 'alpha', { slots: { 'mint-KO': -30 } });
    await bank(me.id, 11, t(10), 'events', {
      slots: [
        {
          mint: 'mint-TSLA',
          symbol: 'TSLAx',
          total: 11,
          events: [
            { code: 'goal', label: '2 goals', points: 8 },
            { code: 'assist', label: 'Assist', points: 3 },
          ],
        },
      ],
      teamEvents: [],
    });

    const card = await h.app.get(MatchWeekService).result(me.id, 'football', h.clock.now());
    expect(card).toMatchObject({
      final: false,
      points: -7,
      manOfTheMatch: { symbol: 'TSLAx', points: 26 },
      turningPoint: { points: -30 },
    });
    expect(card.goals).toEqual([
      expect.objectContaining({ symbol: 'TSLAx', label: '2 goals', points: 8 }),
    ]);
  });
});

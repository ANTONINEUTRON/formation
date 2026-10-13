import { Inject, Injectable, Logger } from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { League } from '../core/db-types.js';
import { CALENDAR } from '../domain/calendar.js';
import type { GameCalendar, MatchWeek } from '../domain/calendar.js';
import type {
  FixtureDto,
  LeagueTableRowDto,
  LiveFixtureDto,
  MatchWeekResultDto,
} from '../domain/dto.js';
import { leagueTable, roundRobin } from '../domain/fixtures.js';
import { SPORT_MODES } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { GOAL_CODES } from './engine/skill.js';
import type { SlotScore } from './engine/types.js';
import { SkillService } from './skill.service.js';

/**
 * The weekly rhythm (SCORING_PLAN.md §2.2). A match week is a window over the
 * points ledger: nothing here scores anything. On each tick this announces
 * kick-off and half-time, and at full time settles private-league fixtures
 * and tells every player how their week went.
 */
@Injectable()
export class MatchWeekService {
  private readonly logger = new Logger(MatchWeekService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CALENDAR) private readonly calendar: GameCalendar,
    private readonly notifications: NotificationsService,
    private readonly xstocks: XStocksService,
    private readonly skill: SkillService,
  ) {}

  /** Runs after each tick has banked. */
  async process(now: number): Promise<void> {
    // Fixtures can come due on any tick (a league created mid-week, a restart).
    await this.settleFixtures(now);
    const current = this.calendar.weekAt(now);
    // Only this week and last: a server that was down doesn't replay history.
    const weeks = current.number > 1 ? [this.calendar.week(current.number - 1), current] : [current];
    for (const week of weeks) {
      await this.ensureWeek(week);
      const marks = await this.db
        .selectFrom('match_weeks')
        .selectAll()
        .where('number', '=', week.number)
        .executeTakeFirstOrThrow();
      const kickOff = week.kickOff.getTime();
      const fullTime = week.fullTime.getTime();
      const halfTime = kickOff + (fullTime - kickOff) / 2;

      if (now >= fullTime) {
        if (!marks.full_time_done_at) await this.fullTime(week, now);
      } else if (now >= halfTime) {
        if (!marks.half_time_sent_at) await this.halfTime(week, now);
      } else if (now >= kickOff && !marks.kick_off_sent_at) {
        await this.kickOff(week, now);
      }
    }
  }

  private async ensureWeek(week: MatchWeek): Promise<void> {
    await this.db
      .insertInto('match_weeks')
      .values({ number: week.number, kick_off: week.kickOff, full_time: week.fullTime })
      .onConflict((oc) => oc.column('number').doNothing())
      .execute();
  }

  /** Marks [column] for [week]; false if another run already did. */
  private async claim(
    week: MatchWeek,
    column: 'kick_off_sent_at' | 'half_time_sent_at' | 'full_time_done_at',
    now: number,
  ): Promise<boolean> {
    const row = await this.db
      .updateTable('match_weeks')
      .set({ [column]: new Date(now) })
      .where('number', '=', week.number)
      .where(column, 'is', null)
      .returning('number')
      .executeTakeFirst();
    return row !== undefined;
  }

  private async kickOff(week: MatchWeek, now: number): Promise<void> {
    if (!(await this.claim(week, 'kick_off_sent_at', now))) return;
    const players = await this.entered();
    await this.notifications.pushMany(
      players.map((p) => ({
        userId: p.userId,
        kind: 'match_week' as const,
        title: `Match week ${week.weekOfSeason} kicks off`,
        body: `Season ${week.season}: your ${label(p.mode)} team is on the pitch until Friday 4pm ET.`,
        data: { week: week.number, mode: p.mode, phase: 'kick_off' },
      })),
    );
  }

  private async halfTime(week: MatchWeek, now: number): Promise<void> {
    if (!(await this.claim(week, 'half_time_sent_at', now))) return;
    const messages = [];
    for (const mode of SPORT_MODES) {
      const board = await this.weekBoard(mode, week);
      for (const [i, row] of board.entries()) {
        messages.push({
          userId: row.userId,
          kind: 'match_week' as const,
          title: 'Half-time',
          body: `Your ${label(mode)} team is on ${signed(row.points)} this week, #${i + 1} of ${board.length}.`,
          data: { week: week.number, mode, phase: 'half_time' },
        });
      }
    }
    await this.notifications.pushMany(messages);
  }

  private async fullTime(week: MatchWeek, now: number): Promise<void> {
    if (!(await this.claim(week, 'full_time_done_at', now))) return;
    await this.settleFixtures(now);
    await this.skill.computeWeek(week, now);

    const messages = [];
    for (const mode of SPORT_MODES) {
      const board = await this.weekBoard(mode, week);
      for (const [i, row] of board.entries()) {
        messages.push({
          userId: row.userId,
          kind: 'match_week' as const,
          title: `Full time: ${signed(row.points)}`,
          body:
            `Match week ${week.weekOfSeason}: #${i + 1} of ${board.length} in ${label(mode)}. ` +
            'The transfer window is open: substitutions are free until Monday 9:30am ET.',
          data: { week: week.number, mode, phase: 'full_time', rank: i + 1 },
        });
      }
    }
    await this.notifications.pushMany(messages);
    this.logger.log(`Match week ${week.number} full time`);
  }

  /** Points every player banked between kick-off and full time, best first. */
  async weekBoard(mode: SportMode, week: MatchWeek): Promise<{ userId: string; points: number }[]> {
    const rows = await this.db
      .selectFrom('points_ledger')
      .innerJoin('users', 'users.id', 'points_ledger.user_id')
      .select((eb) => ['points_ledger.user_id as user_id', eb.fn.sum<string>('points_ledger.points').as('points')])
      .where('points_ledger.sport_mode', '=', mode)
      .where('points_ledger.at', '>=', week.kickOff)
      .where('points_ledger.at', '<=', week.fullTime)
      .where('users.is_seed', '=', false)
      .groupBy('points_ledger.user_id')
      .execute();
    return rows
      .map((r) => ({ userId: r.user_id, points: Number(r.points ?? 0) }))
      .sort((a, b) => b.points - a.points);
  }

  private async entered(): Promise<{ userId: string; mode: SportMode }[]> {
    const rows = await this.db
      .selectFrom('general_entries')
      .innerJoin('users', 'users.id', 'general_entries.user_id')
      .select(['general_entries.user_id as user_id', 'general_entries.sport_mode as mode'])
      .where('users.is_seed', '=', false)
      .execute();
    return rows.map((r) => ({ userId: r.user_id, mode: r.mode }));
  }

  // ── Private-league fixtures ───────────────────────────────────────────────

  /**
   * Schedules a league's head-to-head fixtures: one round robin round for
   * every match week that falls wholly inside it. Duels are already a single
   * fixture, and a league shorter than a match week keeps its plain table.
   */
  async scheduleFixtures(league: League, members: string[]): Promise<number> {
    if (members.length < 3) return 0;
    const start = new Date(league.starts_at).getTime();
    const end = new Date(league.ends_at).getTime();
    const values = [];
    let round = 0;
    for (let w = this.calendar.weekAt(start).number; ; w++) {
      const week = this.calendar.week(w);
      if (week.kickOff.getTime() > end) break;
      if (week.kickOff.getTime() < start || week.fullTime.getTime() > end) continue;
      for (const pairing of roundRobin(members, round)) {
        values.push({
          league_id: league.id,
          week: week.number,
          kick_off: week.kickOff,
          full_time: week.fullTime,
          home_id: pairing.home,
          away_id: pairing.away,
        });
      }
      round++;
    }
    if (values.length === 0) return 0;
    await this.db
      .insertInto('league_fixtures')
      .values(values)
      .onConflict((oc) => oc.columns(['league_id', 'week', 'home_id']).doNothing())
      .execute();
    return round;
  }

  /** Settles every fixture whose match week has reached full time. */
  async settleFixtures(now: number): Promise<number> {
    const due = await this.db
      .selectFrom('league_fixtures')
      .innerJoin('leagues', 'leagues.id', 'league_fixtures.league_id')
      .select([
        'league_fixtures.id as id',
        'league_fixtures.home_id as home_id',
        'league_fixtures.away_id as away_id',
        'league_fixtures.kick_off as kick_off',
        'league_fixtures.full_time as full_time',
        'leagues.sport_mode as mode',
      ])
      .where('league_fixtures.status', '=', 'scheduled')
      .where('league_fixtures.full_time', '<=', new Date(now))
      .execute();

    for (const f of due) {
      const points = async (userId: string | null) => {
        if (!userId) return 0;
        const row = await this.db
          .selectFrom('points_ledger')
          .select((eb) => eb.fn.sum<string>('points').as('total'))
          .where('user_id', '=', userId)
          .where('sport_mode', '=', f.mode)
          .where('at', '>=', new Date(f.kick_off))
          .where('at', '<=', new Date(f.full_time))
          .executeTakeFirst();
        return Math.round(Number(row?.total ?? 0) * 10) / 10;
      };
      await this.db
        .updateTable('league_fixtures')
        .set({
          home_points: await points(f.home_id),
          away_points: await points(f.away_id),
          status: 'final',
        })
        .where('id', '=', f.id)
        .execute();
    }
    return due.length;
  }

  /** [userId]'s fixtures in this match week, scored live from the ledger. */
  async liveFixtures(userId: string, mode: SportMode, now: number): Promise<LiveFixtureDto[]> {
    const week = this.calendar.weekAt(now);
    const rows = await this.db
      .selectFrom('league_fixtures')
      .innerJoin('leagues', 'leagues.id', 'league_fixtures.league_id')
      .select([
        'league_fixtures.league_id as league_id',
        'leagues.name as league_name',
        'league_fixtures.home_id as home_id',
        'league_fixtures.away_id as away_id',
        'league_fixtures.home_points as home_points',
        'league_fixtures.away_points as away_points',
        'league_fixtures.status as status',
      ])
      .where('leagues.sport_mode', '=', mode)
      .where('league_fixtures.week', '=', week.number)
      .where((eb) =>
        eb.or([eb('league_fixtures.home_id', '=', userId), eb('league_fixtures.away_id', '=', userId)]),
      )
      .execute();
    if (rows.length === 0) return [];

    const opponents = rows.flatMap((r) => {
      const other = r.home_id === userId ? r.away_id : r.home_id;
      return other ? [other] : [];
    });
    const names = new Map(
      opponents.length === 0
        ? []
        : (
            await this.db
              .selectFrom('users')
              .select(['id', 'username'])
              .where('id', 'in', opponents)
              .execute()
          ).map((u) => [u.id, u.username]),
    );
    const board = new Map((await this.weekBoard(mode, week)).map((r) => [r.userId, r.points]));

    return rows.map((r) => {
      const home = r.home_id === userId;
      const other = home ? r.away_id : r.home_id;
      const final = r.status === 'final';
      return {
        leagueId: r.league_id,
        leagueName: r.league_name,
        opponent: other ? (names.get(other) ?? 'unknown') : null,
        points: round1(final ? ((home ? r.home_points : r.away_points) ?? 0) : (board.get(userId) ?? 0)),
        opponentPoints: round1(
          final
            ? ((home ? r.away_points : r.home_points) ?? 0)
            : other
              ? (board.get(other) ?? 0)
              : 0,
        ),
        final,
      };
    });
  }

  async fixtures(leagueId: string, names: Map<string, string>): Promise<FixtureDto[]> {
    const rows = await this.db
      .selectFrom('league_fixtures')
      .selectAll()
      .where('league_id', '=', leagueId)
      .orderBy('week')
      .orderBy('id')
      .execute();
    return rows.map((f) => ({
      week: f.week,
      weekOfSeason: this.calendar.week(f.week).weekOfSeason,
      kickOff: new Date(f.kick_off).toISOString(),
      fullTime: new Date(f.full_time).toISOString(),
      homeId: f.home_id,
      homeName: names.get(f.home_id) ?? 'unknown',
      awayId: f.away_id,
      awayName: f.away_id ? (names.get(f.away_id) ?? 'unknown') : null,
      homePoints: f.home_points,
      awayPoints: f.away_points,
      status: f.status,
    }));
  }

  table(members: string[], fixtures: FixtureDto[], names: Map<string, string>): LeagueTableRowDto[] {
    if (fixtures.length === 0) return [];
    return leagueTable(
      members,
      fixtures.flatMap((f) =>
        f.status === 'final'
          ? [
              {
                week: f.week,
                home: f.homeId,
                away: f.awayId,
                homePoints: f.homePoints ?? 0,
                awayPoints: f.awayPoints ?? 0,
              },
            ]
          : [],
      ),
    ).map((row, i) => ({ ...row, rank: i + 1, username: names.get(row.userId) ?? 'unknown' }));
  }

  // ── The full-time result card ─────────────────────────────────────────────

  /**
   * How [userId]'s week went: the score, their man of the match, the goals in
   * order, and the tick that swung it most. Live until full time.
   */
  async result(
    userId: string,
    mode: SportMode,
    now: number,
    weekNumber?: number,
  ): Promise<MatchWeekResultDto> {
    const week = weekNumber ? this.calendar.week(weekNumber) : this.calendar.weekAt(now);
    const [rows, stocks, board] = await Promise.all([
      this.db
        .selectFrom('points_ledger')
        .select(['kind', 'points', 'detail', 'at'])
        .where('user_id', '=', userId)
        .where('sport_mode', '=', mode)
        .where('at', '>=', week.kickOff)
        .where('at', '<=', week.fullTime)
        .orderBy('at')
        .execute(),
      this.xstocks.byMint(),
      this.weekBoard(mode, week),
    ]);
    const symbol = (mint: string) => stocks.get(mint)?.symbol ?? mint;

    const byPick = new Map<string, number>();
    const goals: MatchWeekResultDto['goals'] = [];
    let turningPoint: MatchWeekResultDto['turningPoint'] = null;
    let points = 0;

    for (const row of rows) {
      points += row.points;
      const at = new Date(row.at).toISOString();
      if (row.kind === 'alpha') {
        const detail = (row.detail ?? {}) as { slots?: Record<string, number> };
        for (const [mint, p] of Object.entries(detail.slots ?? {})) {
          byPick.set(mint, (byPick.get(mint) ?? 0) + p);
        }
        if (!turningPoint || Math.abs(row.points) > Math.abs(turningPoint.points)) {
          turningPoint = { at, points: row.points };
        }
      } else if (row.kind === 'events') {
        const detail = (row.detail ?? {}) as { slots?: SlotScore[] };
        for (const slot of detail.slots ?? []) {
          byPick.set(slot.mint, (byPick.get(slot.mint) ?? 0) + slot.total);
          for (const event of slot.events) {
            if (GOAL_CODES.has(event.code) && event.points > 0) {
              goals.push({ at, symbol: slot.symbol, label: event.label, points: event.points });
            }
          }
        }
      }
    }

    // Today's goals so far, flagged provisional until the daily rollup.
    const live = await this.db
      .selectFrom('live_events')
      .select(['symbol', 'label', 'points', 'at', 'code'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .where('status', '=', 'provisional')
      .where('at', '>=', week.kickOff)
      .where('at', '<=', week.fullTime)
      .orderBy('at')
      .execute();
    for (const e of live) {
      if (GOAL_CODES.has(e.code) && e.points > 0) {
        goals.push({
          at: new Date(e.at).toISOString(),
          symbol: e.symbol,
          label: e.label,
          points: e.points,
          provisional: true,
        });
      }
    }

    goals.sort((a, b) => a.at.localeCompare(b.at));

    const best = [...byPick.entries()].sort((a, b) => b[1] - a[1])[0];
    const rank = board.findIndex((r) => r.userId === userId);
    return {
      week: {
        number: week.number,
        season: week.season,
        weekOfSeason: week.weekOfSeason,
        kickOff: week.kickOff.toISOString(),
        fullTime: week.fullTime.toISOString(),
        nextKickOff: week.nextKickOff.toISOString(),
        points: round1(points),
      },
      final: now >= week.fullTime.getTime(),
      points: round1(points),
      rank: rank >= 0 ? rank + 1 : null,
      players: board.length,
      manOfTheMatch: best && best[1] > 0 ? { symbol: symbol(best[0]), points: round1(best[1]) } : null,
      goals,
      turningPoint,
    };
  }
}

const label = (mode: SportMode) => mode.replace('_', ' ');
const round1 = (n: number) => Math.round(n * 10) / 10;
const signed = (n: number) => `${n > 0 ? '+' : ''}${round1(n)} pts`;

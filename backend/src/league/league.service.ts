import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { LeaderboardEntryDto } from '../domain/dto.js';
import { CALENDAR } from '../domain/calendar.js';
import type { GameCalendar } from '../domain/calendar.js';
import { parseLeaguePeriod, SEASON } from '../domain/league-period.js';
import type { LeaguePeriod } from '../domain/league-period.js';
import type { SportMode } from '../domain/sport.js';
import { SKILL_MIN_WEEKS } from '../scoring/engine/skill.js';

const BOARD_SIZE = 100;

/** Raw query parameters, resolved against the app clock. */
export interface PeriodQuery {
  period?: string;
  from?: string;
  to?: string;
}

export interface Standing {
  /** Running total, banked on every tick. */
  points: number;
  todayPoints: number;
  streak: number;
  rank: number;
}

/** A user's points for the selected period, before ranking. */
interface Tally {
  userId: string;
  username: string;
  walletAddress: string;
  points: number;
  todayPoints: number;
  streak: number;
}

@Injectable()
export class LeagueService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(CALENDAR) private readonly calendar: GameCalendar,
  ) {}

  /**
   * Top of the Classic league for [period], plus the current user if they fall
   * below it. All time reads the denormalised season totals; bounded periods
   * add up the finalised gameweeks that ended inside the range. Either way the
   * live gameweek is folded in, so ranks move on every price tick.
   */
  async leaderboard(
    mode: SportMode,
    currentUserId?: string,
    query: PeriodQuery | LeaguePeriod = SEASON,
  ): Promise<LeaderboardEntryDto[]> {
    const period =
      'kind' in query
        ? query
        : parseLeaguePeriod(query.period, query.from, query.to, this.clock.date(), this.calendar);
    const today = await this.todayPoints(mode);
    // The season board reads the running totals; every other period, career
    // (all time) included, is a sum over the ledger.
    const [tallies, skill] = await Promise.all([
      period.kind === 'season'
        ? this.seasonTallies(mode, today)
        : period.kind === 'skill'
          ? this.skillTallies(mode, today)
          : period.kind === 'all_time'
            ? this.careerTallies(mode, today)
            : this.periodTallies(mode, period, today),
      this.skillRatings(mode),
    ]);

    const entries = tallies
      .sort((a, b) => b.points - a.points)
      .slice(0, BOARD_SIZE)
      .map((tally, i) => ({
        ...tally,
        rank: i + 1,
        isCurrentUser: tally.userId === currentUserId,
        skill: skill.get(tally.userId) ?? null,
      }));

    if (currentUserId && !entries.some((e) => e.isCurrentUser)) {
      const mine = tallies.findIndex((t) => t.userId === currentUserId);
      if (mine >= 0) {
        entries.push({
          ...tallies[mine],
          rank: mine + 1,
          isCurrentUser: true,
          skill: skill.get(currentUserId) ?? null,
        });
      }
    }
    return entries;
  }

  /**
   * The Skill board: ranked by skill rating, which never resets, for players
   * with enough weeks behind them. The "points" column carries the rating.
   */
  private async skillTallies(mode: SportMode, today: Map<string, number>): Promise<Tally[]> {
    const [rows, streaks] = await Promise.all([
      this.db
        .selectFrom('skill_ratings')
        .innerJoin('users', 'users.id', 'skill_ratings.user_id')
        .select([
          'skill_ratings.user_id as user_id',
          'skill_ratings.rating as rating',
          'users.username as username',
          'users.wallet_address as wallet_address',
        ])
        .where('skill_ratings.sport_mode', '=', mode)
        .where('skill_ratings.weeks', '>=', SKILL_MIN_WEEKS)
        .orderBy('skill_ratings.rating', 'desc')
        .execute(),
      this.streaks(mode),
    ]);
    return rows.map((row) => ({
      userId: row.user_id,
      username: row.username,
      walletAddress: row.wallet_address,
      points: row.rating,
      todayPoints: today.get(row.user_id) ?? 0,
      streak: streaks.get(row.user_id) ?? 0,
    }));
  }

  private async skillRatings(mode: SportMode): Promise<Map<string, number>> {
    const rows = await this.db
      .selectFrom('skill_ratings')
      .select(['user_id', 'rating'])
      .where('sport_mode', '=', mode)
      .execute();
    return new Map(rows.map((r) => [r.user_id, r.rating]));
  }

  /** This season's running totals, which every tick has already banked into. */
  private async seasonTallies(
    mode: SportMode,
    today: Map<string, number>,
  ): Promise<Tally[]> {
    const rows = await this.db
      .selectFrom('classic_scores')
      .innerJoin('users', 'users.id', 'classic_scores.user_id')
      .select([
        'classic_scores.user_id as user_id',
        'classic_scores.total_points as total_points',
        this.streak(),
        'users.username as username',
        'users.wallet_address as wallet_address',
      ])
      .where('classic_scores.sport_mode', '=', mode)
      .where('users.suspended_at', 'is', null)
      .orderBy('classic_scores.total_points', 'desc')
      .limit(BOARD_SIZE)
      .execute();

    return rows.map((row) => ({
      userId: row.user_id,
      username: row.username,
      walletAddress: row.wallet_address,
      points: row.total_points,
      todayPoints: today.get(row.user_id) ?? 0,
      streak: row.streak,
    }));
  }

  /**
   * A whole career: this season's running total plus every finished season.
   * Read from the totals rather than the ledger, so players whose points were
   * never banked tick by tick (the demo players) are on it too.
   */
  private async careerTallies(mode: SportMode, today: Map<string, number>): Promise<Tally[]> {
    const rows = await this.db
      .selectFrom('classic_scores')
      .innerJoin('users', 'users.id', 'classic_scores.user_id')
      .leftJoin(
        (eb) =>
          eb
            .selectFrom('season_results')
            .select((s) => ['user_id', s.fn.sum<string>('points').as('points')])
            .where('sport_mode', '=', mode)
            .groupBy('user_id')
            .as('past'),
        (join) => join.onRef('past.user_id', '=', 'classic_scores.user_id'),
      )
      .select([
        'classic_scores.user_id as user_id',
        'classic_scores.total_points as total_points',
        this.streak(),
        'past.points as past_points',
        'users.username as username',
        'users.wallet_address as wallet_address',
      ])
      .where('classic_scores.sport_mode', '=', mode)
      .where('users.suspended_at', 'is', null)
      .execute();

    return rows.map((row) => ({
      userId: row.user_id,
      username: row.username,
      walletAddress: row.wallet_address,
      points: Math.round((row.total_points + Number(row.past_points ?? 0)) * 10) / 10,
      todayPoints: today.get(row.user_id) ?? 0,
      streak: row.streak,
    }));
  }

  /** Points banked inside [period], summed straight from the ledger. */
  private async periodTallies(
    mode: SportMode,
    period: LeaguePeriod,
    today: Map<string, number>,
  ): Promise<Tally[]> {
    let query = this.db
      .selectFrom('points_ledger')
      .innerJoin('users', 'users.id', 'points_ledger.user_id')
      .select((eb) => [
        'points_ledger.user_id as user_id',
        'users.username as username',
        'users.wallet_address as wallet_address',
        eb.fn.sum<string>('points_ledger.points').as('points'),
      ])
      .where('points_ledger.sport_mode', '=', mode)
      .where('users.suspended_at', 'is', null)
      .groupBy(['points_ledger.user_id', 'users.username', 'users.wallet_address']);

    if (period.from) query = query.where('points_ledger.at', '>=', period.from);
    if (period.to) query = query.where('points_ledger.at', '<=', period.to);

    const rows = await query.execute();
    const streaks = await this.streaks(mode);

    return rows.map((row) => ({
      userId: row.user_id,
      username: row.username,
      walletAddress: row.wallet_address,
      // pg returns sum() as a string.
      points: Number(row.points ?? 0),
      todayPoints: today.get(row.user_id) ?? 0,
      streak: streaks.get(row.user_id) ?? 0,
    }));
  }

  /** Points every player has banked so far today, for the movement column. */
  private async todayPoints(mode: SportMode): Promise<Map<string, number>> {
    const start = new Date(this.clock.now());
    start.setUTCHours(0, 0, 0, 0);
    const rows = await this.db
      .selectFrom('points_ledger')
      .select((eb) => ['user_id', eb.fn.sum<string>('points').as('points')])
      .where('sport_mode', '=', mode)
      .where('at', '>=', start)
      .groupBy('user_id')
      .execute();
    return new Map(rows.map((r) => [r.user_id, Number(r.points ?? 0)]));
  }

  private async streaks(mode: SportMode): Promise<Map<string, number>> {
    const rows = await this.db
      .selectFrom('classic_scores')
      .innerJoin('users', 'users.id', 'classic_scores.user_id')
      .select(['classic_scores.user_id as user_id', this.streak()])
      .where('classic_scores.sport_mode', '=', mode)
      .execute();
    return new Map(rows.map((r) => [r.user_id, r.streak]));
  }

  /**
   * The streak shown on boards and profiles: days in a row the Manager has
   * opened the app (users.visit_streak), or 0 once a day has been missed,
   * judged in their own time zone. Seeds never visit, so they keep the
   * streak they were seeded with. Needs `users` and `classic_scores` joined.
   */
  private streak() {
    const now = this.clock.date();
    return sql<number>`case
      when users.is_seed then classic_scores.streak
      when users.last_visit_day >= ((${now}::timestamptz at time zone coalesce(
        (select p.time_zone from push_preferences p where p.user_id = users.id), 'UTC'))::date - 1)
        then users.visit_streak
      else 0 end`.as('streak');
  }

  /** The user's all-time points, streak and rank, or null if they haven't drafted. */
  async standing(userId: string, mode: SportMode): Promise<Standing | null> {
    const row = await this.db
      .selectFrom('classic_scores')
      .innerJoin('users', 'users.id', 'classic_scores.user_id')
      .select(['classic_scores.total_points as total_points', this.streak()])
      .where('classic_scores.user_id', '=', userId)
      .where('classic_scores.sport_mode', '=', mode)
      .executeTakeFirst();
    if (!row) return null;

    const ahead = await this.db
      .selectFrom('classic_scores')
      .innerJoin('users', 'users.id', 'classic_scores.user_id')
      .select((eb) => eb.fn.countAll<number>().as('count'))
      .where('classic_scores.sport_mode', '=', mode)
      .where('classic_scores.total_points', '>', row.total_points)
      .where('users.suspended_at', 'is', null)
      .executeTakeFirst();

    return {
      points: row.total_points,
      todayPoints: (await this.todayPoints(mode)).get(userId) ?? 0,
      streak: row.streak,
      rank: Number(ahead?.count ?? 0) + 1,
    };
  }
}

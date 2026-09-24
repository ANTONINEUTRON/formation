import { Inject, Injectable } from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { LeaderboardEntryDto } from '../domain/dto.js';
import { ALL_TIME, parseLeaguePeriod } from '../domain/league-period.js';
import type { LeaguePeriod } from '../domain/league-period.js';
import type { SportMode } from '../domain/sport.js';

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
    query: PeriodQuery | LeaguePeriod = ALL_TIME,
  ): Promise<LeaderboardEntryDto[]> {
    const period =
      'kind' in query
        ? query
        : parseLeaguePeriod(query.period, query.from, query.to, this.clock.date());
    const today = await this.todayPoints(mode);
    const tallies =
      period.from === null && period.to === null
        ? await this.allTimeTallies(mode, today)
        : await this.periodTallies(mode, period, today);

    const entries = tallies
      .sort((a, b) => b.points - a.points)
      .slice(0, BOARD_SIZE)
      .map((tally, i) => ({
        ...tally,
        rank: i + 1,
        isCurrentUser: tally.userId === currentUserId,
      }));

    if (currentUserId && !entries.some((e) => e.isCurrentUser)) {
      const mine = tallies.findIndex((t) => t.userId === currentUserId);
      if (mine >= 0) {
        entries.push({ ...tallies[mine], rank: mine + 1, isCurrentUser: true });
      }
    }
    return entries;
  }

  /** Running totals, which every tick has already banked into. */
  private async allTimeTallies(
    mode: SportMode,
    today: Map<string, number>,
  ): Promise<Tally[]> {
    const rows = await this.db
      .selectFrom('classic_scores')
      .innerJoin('users', 'users.id', 'classic_scores.user_id')
      .select([
        'classic_scores.user_id as user_id',
        'classic_scores.total_points as total_points',
        'classic_scores.streak as streak',
        'users.username as username',
        'users.wallet_address as wallet_address',
      ])
      .where('classic_scores.sport_mode', '=', mode)
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
      .select(['user_id', 'streak'])
      .where('sport_mode', '=', mode)
      .execute();
    return new Map(rows.map((r) => [r.user_id, r.streak]));
  }

  /** The user's all-time points, streak and rank, or null if they haven't drafted. */
  async standing(userId: string, mode: SportMode): Promise<Standing | null> {
    const row = await this.db
      .selectFrom('classic_scores')
      .select(['total_points', 'streak'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    if (!row) return null;

    const ahead = await this.db
      .selectFrom('classic_scores')
      .select((eb) => eb.fn.countAll<number>().as('count'))
      .where('sport_mode', '=', mode)
      .where('total_points', '>', row.total_points)
      .executeTakeFirst();

    return {
      points: row.total_points,
      todayPoints: (await this.todayPoints(mode)).get(userId) ?? 0,
      streak: row.streak,
      rank: Number(ahead?.count ?? 0) + 1,
    };
  }
}

import { Inject, Injectable } from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { LeaderboardEntryDto } from '../domain/dto.js';
import type { SportMode } from '../domain/sport.js';
import { GameweekService } from '../gameweek/gameweek.service.js';
import { UsersService } from '../users/users.service.js';

const BOARD_SIZE = 100;

export interface Standing {
  /** Season total plus the live gameweek. */
  points: number;
  gameweekPoints: number;
  streak: number;
  rank: number;
}

@Injectable()
export class LeagueService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly users: UsersService,
    private readonly gameweeks: GameweekService,
  ) {}

  /** Top of the Classic league, plus the current user if they're below it. */
  async leaderboard(mode: SportMode, currentUserId?: string): Promise<LeaderboardEntryDto[]> {
    const live = await this.livePoints(mode);
    const rows = await this.db
      .selectFrom('classic_scores')
      .innerJoin('users', 'users.id', 'classic_scores.user_id')
      .select([
        'classic_scores.user_id as user_id',
        'classic_scores.total_points as total_points',
        'classic_scores.last_gameweek_points as last_gameweek_points',
        'classic_scores.streak as streak',
        'users.username as username',
        'users.wallet_address as wallet_address',
      ])
      .where('classic_scores.sport_mode', '=', mode)
      .orderBy('classic_scores.total_points', 'desc')
      .limit(BOARD_SIZE)
      .execute();

    const entries = rows
      .map((row) => ({
        rank: 0,
        userId: row.user_id,
        username: row.username,
        walletAddress: row.wallet_address,
        points: row.total_points + (live.get(row.user_id) ?? 0),
        gameweekPoints: live.get(row.user_id) ?? row.last_gameweek_points,
        streak: row.streak,
        isCurrentUser: row.user_id === currentUserId,
      }))
      .sort((a, b) => b.points - a.points)
      .map((entry, i) => ({ ...entry, rank: i + 1 }));

    if (currentUserId && !entries.some((e) => e.isCurrentUser)) {
      const standing = await this.standing(currentUserId, mode);
      const me = (await this.users.getMany([currentUserId])).get(currentUserId);
      if (standing && me) {
        entries.push({
          rank: standing.rank,
          userId: me.id,
          username: me.username,
          walletAddress: me.wallet_address,
          points: standing.points,
          gameweekPoints: standing.gameweekPoints,
          streak: standing.streak,
          isCurrentUser: true,
        });
      }
    }
    return entries;
  }

  /** The user's points, streak and rank, or null if they haven't drafted. */
  async standing(userId: string, mode: SportMode): Promise<Standing | null> {
    const row = await this.db
      .selectFrom('classic_scores')
      .select(['total_points', 'last_gameweek_points', 'streak'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    if (!row) return null;

    const live = await this.livePoints(mode);
    const points = row.total_points + (live.get(userId) ?? 0);

    const ahead = await this.db
      .selectFrom('classic_scores')
      .select((eb) => eb.fn.countAll<number>().as('count'))
      .where('sport_mode', '=', mode)
      .where('total_points', '>', row.total_points)
      .executeTakeFirst();

    return {
      points,
      gameweekPoints: live.get(userId) ?? row.last_gameweek_points,
      streak: row.streak,
      rank: Number(ahead?.count ?? 0) + 1,
    };
  }

  /** Points scored so far in the live gameweek, by user. */
  private async livePoints(mode: SportMode): Promise<Map<string, number>> {
    const gameweek = await this.gameweeks.current(mode);
    if (!gameweek || gameweek.status !== 'live') return new Map();
    return this.gameweeks.livePointsByUser(gameweek.id);
  }
}

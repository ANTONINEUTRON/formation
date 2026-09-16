import { Injectable } from '@nestjs/common';
import { DbService, unwrap } from '../core/db.service.js';
import { LeaderboardEntryDto } from '../domain/dto.js';
import { SportMode } from '../domain/sport.js';
import { UsersService } from '../users/users.service.js';

interface ScoreRow {
  user_id: string;
  total_points: number;
  streak: number;
  users: { username: string; wallet_address: string };
}

const BOARD_SIZE = 100;

@Injectable()
export class LeagueService {
  constructor(
    private readonly db: DbService,
    private readonly users: UsersService,
  ) {}

  /** Top of the Classic league, plus the current user if they're below it. */
  async leaderboard(
    mode: SportMode,
    currentUserId?: string,
  ): Promise<LeaderboardEntryDto[]> {
    // users is a to-one join, but the untyped client infers an array.
    const rows = unwrap(
      await this.db.supabase
        .from('classic_scores')
        .select('user_id, total_points, streak, users!inner(username, wallet_address)')
        .eq('sport_mode', mode)
        .order('total_points', { ascending: false })
        .limit(BOARD_SIZE),
    ) as unknown as ScoreRow[];
    const entries = rows.map((r, i) => ({
      rank: i + 1,
      userId: r.user_id,
      username: r.users.username,
      walletAddress: r.users.wallet_address,
      points: Number(r.total_points),
      streak: r.streak,
      isCurrentUser: r.user_id === currentUserId,
    }));

    if (currentUserId && !entries.some((e) => e.isCurrentUser)) {
      const mine = await this.standing(currentUserId, mode);
      const me = (await this.users.getMany([currentUserId])).get(currentUserId);
      if (mine && me) {
        entries.push({
          rank: mine.rank,
          userId: me.id,
          username: me.username,
          walletAddress: me.wallet_address,
          points: mine.points,
          streak: mine.streak,
          isCurrentUser: true,
        });
      }
    }
    return entries;
  }

  /** The user's points, streak and rank, or null if they haven't drafted. */
  async standing(
    userId: string,
    mode: SportMode,
  ): Promise<{ points: number; streak: number; rank: number } | null> {
    const row: { total_points: number; streak: number } | null = unwrap(
      await this.db.supabase
        .from('classic_scores')
        .select('total_points, streak')
        .eq('user_id', userId)
        .eq('sport_mode', mode)
        .maybeSingle(),
    );
    if (!row) return null;
    const { count, error } = await this.db.supabase
      .from('classic_scores')
      .select('user_id', { count: 'exact', head: true })
      .eq('sport_mode', mode)
      .gt('total_points', row.total_points);
    unwrap({ data: null, error });
    return {
      points: Number(row.total_points),
      streak: row.streak,
      rank: (count ?? 0) + 1,
    };
  }
}

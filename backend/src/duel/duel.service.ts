import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { DbService, unwrap } from '../core/db.service.js';
import { AuthUser, DuelDto } from '../domain/dto.js';
import { DUEL_DURATION_HOURS, SportMode } from '../domain/sport.js';
import { RosterService } from '../roster/roster.service.js';
import { scoreSnapshots, SnapshotRow } from '../scoring/score-window.js';
import { metaOf, ScoringService, SNAPSHOT_COLUMNS } from '../scoring/scoring.service.js';
import { TrophyService } from '../trophy/trophy.service.js';
import { UserRow, UsersService } from '../users/users.service.js';

interface DuelRow {
  id: string;
  challenger_id: string;
  opponent_id: string;
  sport_mode: SportMode;
  duration_hours: number;
  status: DuelDto['status'];
  start_time: string | null;
  end_time: string | null;
  challenger_return_pct: number | null;
  opponent_return_pct: number | null;
  winner_id: string | null;
}

/** Peer-to-peer head-to-head duels (spec §3.4). No funds ever move. */
@Injectable()
export class DuelService {
  private readonly logger = new Logger(DuelService.name);

  constructor(
    private readonly db: DbService,
    private readonly users: UsersService,
    private readonly rosters: RosterService,
    private readonly scoring: ScoringService,
    private readonly trophies: TrophyService,
  ) {}

  async list(user: AuthUser, mode: SportMode): Promise<DuelDto[]> {
    const rows: DuelRow[] = unwrap(
      await this.db.supabase
        .from('duels')
        .select('*')
        .eq('sport_mode', mode)
        .or(`challenger_id.eq.${user.id},opponent_id.eq.${user.id}`)
        .order('created_at', { ascending: false })
        .limit(50),
    );
    return this.toDtos(rows, user.id, { live: true });
  }

  async create(
    user: AuthUser,
    mode: SportMode,
    opponentHandle: string,
    durationHours: number,
  ): Promise<DuelDto> {
    if (!(DUEL_DURATION_HOURS as readonly number[]).includes(durationHours)) {
      throw new BadRequestException(
        `durationHours must be one of ${DUEL_DURATION_HOURS.join(', ')}`,
      );
    }
    const opponent = await this.users.findByHandle(opponentHandle);
    if (opponent.id === user.id) {
      throw new BadRequestException("You can't duel yourself");
    }
    if (!(await this.rosters.isComplete(user.id, mode))) {
      throw new BadRequestException('Finish your team before challenging someone');
    }

    const row: DuelRow = unwrap(
      await this.db.supabase
        .from('duels')
        .insert({
          challenger_id: user.id,
          opponent_id: opponent.id,
          sport_mode: mode,
          duration_hours: durationHours,
        })
        .select('*')
        .single(),
    );
    return (await this.toDtos([row], user.id))[0];
  }

  async respond(user: AuthUser, duelId: string, accept: boolean): Promise<DuelDto> {
    const duel = await this.get(duelId);
    if (duel.opponent_id !== user.id) {
      throw new ForbiddenException('Only the challenged player can respond');
    }
    if (duel.status !== 'pending') {
      throw new BadRequestException('This duel is no longer pending');
    }

    const db = this.db.supabase;
    if (!accept) {
      unwrap(await db.from('duels').update({ status: 'declined' }).eq('id', duelId));
      return (await this.toDtos([{ ...duel, status: 'declined' }], user.id))[0];
    }

    if (!(await this.rosters.isComplete(user.id, duel.sport_mode))) {
      throw new BadRequestException('Finish your team before accepting');
    }

    // Start snapshots fix each side's baseline at accept time.
    const players = await this.users.getMany([duel.challenger_id, duel.opponent_id]);
    const start = new Date();
    for (const player of players.values()) {
      const rows = await this.scoring.snapshotRoster(player.id, player.wallet_address, duel.sport_mode);
      if (rows.length === 0) continue;
      unwrap(
        await db.from('duel_snapshots').insert(
          rows.map((r) => ({
            ...r,
            duel_id: duelId,
            user_id: player.id,
            checkpoint: 'start',
            captured_at: start.toISOString(),
          })),
        ),
      );
    }

    const updated: DuelRow = unwrap(
      await db
        .from('duels')
        .update({
          status: 'active',
          start_time: start.toISOString(),
          end_time: new Date(start.getTime() + duel.duration_hours * 3_600_000).toISOString(),
        })
        .eq('id', duelId)
        .select('*')
        .single(),
    );
    return (await this.toDtos([updated], user.id, { live: true }))[0];
  }

  @Cron(CronExpression.EVERY_MINUTE)
  async settleDue() {
    const due: { id: string }[] = unwrap(
      await this.db.supabase
        .from('duels')
        .select('id')
        .eq('status', 'active')
        .lte('end_time', new Date().toISOString()),
    );
    for (const { id } of due) {
      try {
        await this.settle(id);
      } catch (e) {
        this.logger.warn(`Settling duel ${id} failed: ${String(e)}`);
      }
    }
  }

  /** Reads both wallets now, scores the window, records the winner. */
  async settle(duelId: string, viewerId = ''): Promise<DuelDto> {
    const duel = await this.get(duelId);
    if (duel.status !== 'active') {
      throw new BadRequestException('Duel is not active');
    }

    const db = this.db.supabase;
    const players = await this.users.getMany([duel.challenger_id, duel.opponent_id]);
    const returns = new Map<string, number>();
    for (const player of players.values()) {
      const start = await this.snapshots(duelId, player.id, 'start');
      const end = await this.scoring.snapshotSlots(
        player.wallet_address,
        start.map(metaOf),
        { fresh: true },
      );
      if (end.length > 0) {
        unwrap(
          await db.from('duel_snapshots').insert(
            end.map((r) => ({ ...r, duel_id: duelId, user_id: player.id, checkpoint: 'end' })),
          ),
        );
      }
      returns.set(player.id, scoreSnapshots(start, end).returnPct);
    }

    const c = returns.get(duel.challenger_id) ?? 0;
    const o = returns.get(duel.opponent_id) ?? 0;
    const winnerId = c > o ? duel.challenger_id : o > c ? duel.opponent_id : null;

    // Guard on status so a concurrent settle (cron + admin) awards once.
    const settled: DuelRow[] = unwrap(
      await db
        .from('duels')
        .update({
          status: 'settled',
          end_time: new Date().toISOString(),
          challenger_return_pct: c,
          opponent_return_pct: o,
          winner_id: winnerId,
        })
        .eq('id', duelId)
        .eq('status', 'active')
        .select('*'),
    );
    if (settled.length === 0) {
      throw new BadRequestException('Duel was already settled');
    }

    if (winnerId) {
      const loserId = winnerId === duel.challenger_id ? duel.opponent_id : duel.challenger_id;
      await this.updateStreaks(winnerId, loserId, duel.sport_mode);
      const winner = players.get(winnerId)!;
      await this.trophies.award({
        userId: winnerId,
        wallet: winner.wallet_address,
        mode: duel.sport_mode,
        title: `Duel win vs ${players.get(loserId)?.username ?? 'rival'}`,
        duelId,
      });
    }
    return (await this.toDtos(settled, viewerId))[0];
  }

  private async get(duelId: string): Promise<DuelRow> {
    const row: DuelRow | null = unwrap(
      await this.db.supabase.from('duels').select('*').eq('id', duelId).maybeSingle(),
    );
    if (!row) throw new NotFoundException('Duel not found');
    return row;
  }

  private async snapshots(
    duelId: string,
    userId: string,
    checkpoint: 'start' | 'end',
  ): Promise<SnapshotRow[]> {
    return unwrap(
      await this.db.supabase
        .from('duel_snapshots')
        .select(SNAPSHOT_COLUMNS)
        .eq('duel_id', duelId)
        .eq('user_id', userId)
        .eq('checkpoint', checkpoint),
    );
  }

  private async updateStreaks(winnerId: string, loserId: string, mode: SportMode) {
    const db = this.db.supabase;
    const winner: { streak: number } | null = unwrap(
      await db
        .from('classic_scores')
        .select('streak')
        .eq('user_id', winnerId)
        .eq('sport_mode', mode)
        .maybeSingle(),
    );
    unwrap(
      await db
        .from('classic_scores')
        .update({ streak: (winner?.streak ?? 0) + 1 })
        .eq('user_id', winnerId)
        .eq('sport_mode', mode),
    );
    unwrap(
      await db
        .from('classic_scores')
        .update({ streak: 0 })
        .eq('user_id', loserId)
        .eq('sport_mode', mode),
    );
  }

  private async toDtos(
    rows: DuelRow[],
    viewerId: string,
    { live = false } = {},
  ): Promise<DuelDto[]> {
    const users = await this.users.getMany(
      rows.flatMap((r) => [r.challenger_id, r.opponent_id]),
    );
    const entry = (user: UserRow | undefined, id: string) => ({
      rank: 0,
      userId: id,
      username: user?.username ?? 'unknown',
      walletAddress: user?.wallet_address ?? '',
      points: 0,
      streak: 0,
      isCurrentUser: id === viewerId,
    });

    return Promise.all(
      rows.map(async (r) => {
        let challengerReturnPct = r.challenger_return_pct;
        let opponentReturnPct = r.opponent_return_pct;
        if (live && r.status === 'active') {
          [challengerReturnPct, opponentReturnPct] = await Promise.all([
            this.liveReturn(r.id, users.get(r.challenger_id)),
            this.liveReturn(r.id, users.get(r.opponent_id)),
          ]);
        }
        return {
          id: r.id,
          challenger: entry(users.get(r.challenger_id), r.challenger_id),
          opponent: entry(users.get(r.opponent_id), r.opponent_id),
          mode: r.sport_mode,
          durationHours: r.duration_hours,
          status: r.status,
          startTime: r.start_time,
          endTime: r.end_time,
          challengerReturnPct,
          opponentReturnPct,
          winnerId: r.winner_id,
        };
      }),
    );
  }

  /** Return so far for one side of an active duel (cached chain reads). */
  private async liveReturn(duelId: string, user?: UserRow): Promise<number> {
    if (!user) return 0;
    const start = await this.snapshots(duelId, user.id, 'start');
    const now = await this.scoring.snapshotSlots(user.wallet_address, start.map(metaOf));
    return scoreSnapshots(start, now).returnPct;
  }
}

import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { Duel, User } from '../core/db-types.js';
import type { AuthUser, DuelCategoryDto, DuelDto } from '../domain/dto.js';
import { DUEL_DURATION_HOURS } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { parseJson } from '../gameweek/gameweek.service.js';
import { RosterService } from '../roster/roster.service.js';
import { EntryScoringService } from '../scoring/entry-scoring.service.js';
import { basketballCategories, sideStats, teamIndex } from '../scoring/engine/categories.js';
import type { EntryBreakdown, LineupSnapshot } from '../scoring/engine/types.js';
import { TrophyService } from '../trophy/trophy.service.js';
import { UsersService } from '../users/users.service.js';

interface SideResult {
  points: number;
  breakdown: EntryBreakdown;
  stats: ReturnType<typeof sideStats>;
}

/** Peer-to-peer head-to-head duels (spec §3.4). No funds ever move. */
@Injectable()
export class DuelService {
  private readonly logger = new Logger(DuelService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly users: UsersService,
    private readonly rosters: RosterService,
    private readonly scoring: EntryScoringService,
    private readonly trophies: TrophyService,
  ) {}

  async list(user: AuthUser, mode: SportMode): Promise<DuelDto[]> {
    const rows = await this.db
      .selectFrom('duels')
      .selectAll()
      .where('sport_mode', '=', mode)
      .where((eb) =>
        eb.or([eb('challenger_id', '=', user.id), eb('opponent_id', '=', user.id)]),
      )
      .orderBy('created_at', 'desc')
      .limit(50)
      .execute();
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

    const row = await this.db
      .insertInto('duels')
      .values({
        challenger_id: user.id,
        opponent_id: opponent.id,
        sport_mode: mode,
        duration_hours: durationHours,
      })
      .returningAll()
      .executeTakeFirstOrThrow();
    return (await this.toDtos([row], user.id))[0];
  }

  /** Accepting locks both lineups and starts the window. */
  async respond(user: AuthUser, duelId: string, accept: boolean): Promise<DuelDto> {
    const duel = await this.get(duelId);
    if (duel.opponent_id !== user.id) {
      throw new ForbiddenException('Only the challenged player can respond');
    }
    if (duel.status !== 'pending') {
      throw new BadRequestException('This duel is no longer pending');
    }

    if (!accept) {
      await this.db
        .updateTable('duels')
        .set({ status: 'declined' })
        .where('id', '=', duelId)
        .execute();
      return (await this.toDtos([{ ...duel, status: 'declined' }], user.id))[0];
    }
    if (!(await this.rosters.isComplete(user.id, duel.sport_mode))) {
      throw new BadRequestException('Finish your team before accepting');
    }

    const players = await this.users.getMany([duel.challenger_id, duel.opponent_id]);
    const start = this.clock.date();
    for (const player of players.values()) {
      const snapshot = await this.scoring.lockLineup(
        player.id,
        player.wallet_address,
        duel.sport_mode,
      );
      if (!snapshot) {
        throw new BadRequestException(
          `${player.username} has not finished their ${duel.sport_mode} team`,
        );
      }
      await this.db
        .insertInto('score_entries')
        .values({
          context: 'duel',
          context_id: duelId,
          user_id: player.id,
          sport_mode: duel.sport_mode,
          snapshot: JSON.stringify(snapshot),
        })
        .onConflict((oc) => oc.columns(['context', 'context_id', 'user_id']).doNothing())
        .execute();
    }

    const updated = await this.db
      .updateTable('duels')
      .set({
        status: 'active',
        start_time: start,
        end_time: new Date(start.getTime() + duel.duration_hours * 3_600_000),
      })
      .where('id', '=', duelId)
      .returningAll()
      .executeTakeFirstOrThrow();
    return (await this.toDtos([updated], user.id, { live: true }))[0];
  }

  @Cron(CronExpression.EVERY_MINUTE)
  async settleDue() {
    const due = await this.db
      .selectFrom('duels')
      .select('id')
      .where('status', '=', 'active')
      .where('end_time', '<=', this.clock.date())
      .execute();
    for (const { id } of due) {
      try {
        await this.settle(id);
      } catch (e) {
        this.logger.warn(`Settling duel ${id} failed: ${String(e)}`);
      }
    }
  }

  /**
   * Scores both locked lineups over the duel window. Points decide football
   * and American Football; basketball is won on categories.
   */
  async settle(duelId: string, viewerId = ''): Promise<DuelDto> {
    const duel = await this.get(duelId);
    if (duel.status !== 'active') {
      throw new BadRequestException('Duel is not active');
    }
    const end = this.clock.date();
    const results = await this.scoreSides(duel, end, { fresh: true });

    const challenger = results.get(duel.challenger_id);
    const opponent = results.get(duel.opponent_id);
    const categories =
      duel.sport_mode === 'basketball' && challenger && opponent
        ? basketballCategories(challenger.stats, opponent.stats)
        : null;

    const challengerPoints = challenger?.points ?? 0;
    const opponentPoints = opponent?.points ?? 0;
    const winnerSide = categories
      ? categories.winner
      : challengerPoints > opponentPoints
        ? 'challenger'
        : opponentPoints > challengerPoints
          ? 'opponent'
          : 'tie';
    const winnerId =
      winnerSide === 'challenger'
        ? duel.challenger_id
        : winnerSide === 'opponent'
          ? duel.opponent_id
          : null;

    // Guarded on status so a concurrent settle (cron + admin) awards once.
    const settled = await this.db
      .updateTable('duels')
      .set({
        status: 'settled',
        end_time: end,
        challenger_points: challengerPoints,
        opponent_points: opponentPoints,
        result: categories ? JSON.stringify(categories.categories) : null,
        winner_id: winnerId,
      })
      .where('id', '=', duelId)
      .where('status', '=', 'active')
      .returningAll()
      .executeTakeFirst();
    if (!settled) throw new BadRequestException('Duel was already settled');

    for (const [userId, result] of results) {
      await this.db
        .updateTable('score_entries')
        .set({
          final_points: result.points,
          live_points: result.points,
          breakdown: JSON.stringify(result.breakdown),
          updated_at: end,
        })
        .where('context', '=', 'duel')
        .where('context_id', '=', duelId)
        .where('user_id', '=', userId)
        .execute();
    }

    if (winnerId) {
      const players = await this.users.getMany([duel.challenger_id, duel.opponent_id]);
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
    return (await this.toDtos([settled], viewerId))[0];
  }

  /** Scores both sides of a duel over [start, until]. */
  private async scoreSides(
    duel: Duel,
    until: Date,
    { fresh = false } = {},
  ): Promise<Map<string, SideResult>> {
    const results = new Map<string, SideResult>();
    if (!duel.start_time) return results;
    const window = this.scoring.window(new Date(duel.start_time), until);

    const entries = await this.db
      .selectFrom('score_entries')
      .innerJoin('users', 'users.id', 'score_entries.user_id')
      .select([
        'score_entries.user_id as user_id',
        'score_entries.snapshot as snapshot',
        'users.wallet_address as wallet_address',
      ])
      .where('score_entries.context', '=', 'duel')
      .where('score_entries.context_id', '=', duel.id)
      .execute();

    for (const entry of entries) {
      const snapshot = parseJson<LineupSnapshot>(entry.snapshot);
      if (!snapshot) continue;
      const { breakdown } = await this.scoring.score(snapshot, entry.wallet_address, window, {
        fresh,
      });
      const prices = await this.scoring.priceBook(
        snapshot.slots.map((s) => s.mint),
        window,
      );
      results.set(entry.user_id, {
        points: breakdown.total,
        breakdown,
        stats: sideStats(breakdown, teamIndex(snapshot.slots, prices, window)),
      });
    }
    return results;
  }

  private async get(duelId: string): Promise<Duel> {
    const row = await this.db
      .selectFrom('duels')
      .selectAll()
      .where('id', '=', duelId)
      .executeTakeFirst();
    if (!row) throw new NotFoundException('Duel not found');
    return row;
  }

  private async updateStreaks(winnerId: string, loserId: string, mode: SportMode) {
    await this.db
      .updateTable('classic_scores')
      .set((eb) => ({ streak: eb(eb.ref('streak'), '+', 1) }))
      .where('user_id', '=', winnerId)
      .where('sport_mode', '=', mode)
      .execute();
    await this.db
      .updateTable('classic_scores')
      .set({ streak: 0 })
      .where('user_id', '=', loserId)
      .where('sport_mode', '=', mode)
      .execute();
  }

  private async toDtos(
    rows: Duel[],
    viewerId: string,
    { live = false } = {},
  ): Promise<DuelDto[]> {
    const users = await this.users.getMany(
      rows.flatMap((r) => [r.challenger_id, r.opponent_id]),
    );
    const entry = (user: User | undefined, id: string) => ({
      rank: 0,
      userId: id,
      username: user?.username ?? 'unknown',
      walletAddress: user?.wallet_address ?? '',
      points: 0,
      gameweekPoints: 0,
      streak: 0,
      isCurrentUser: id === viewerId,
    });

    return Promise.all(
      rows.map(async (row) => {
        let challengerPoints = row.challenger_points;
        let opponentPoints = row.opponent_points;
        let categories = parseJson<DuelCategoryDto[]>(row.result) ?? null;
        let challengerBreakdown: EntryBreakdown | null = null;
        let opponentBreakdown: EntryBreakdown | null = null;

        if (live && row.status === 'active') {
          const results = await this.scoreSides(row, this.clock.date());
          const challenger = results.get(row.challenger_id);
          const opponent = results.get(row.opponent_id);
          challengerPoints = challenger?.points ?? 0;
          opponentPoints = opponent?.points ?? 0;
          challengerBreakdown = challenger?.breakdown ?? null;
          opponentBreakdown = opponent?.breakdown ?? null;
          categories =
            row.sport_mode === 'basketball' && challenger && opponent
              ? basketballCategories(challenger.stats, opponent.stats).categories
              : null;
        }

        return {
          id: row.id,
          challenger: entry(users.get(row.challenger_id), row.challenger_id),
          opponent: entry(users.get(row.opponent_id), row.opponent_id),
          mode: row.sport_mode,
          durationHours: row.duration_hours,
          status: row.status,
          startTime: row.start_time ? new Date(row.start_time).toISOString() : null,
          endTime: row.end_time ? new Date(row.end_time).toISOString() : null,
          challengerPoints,
          opponentPoints,
          categories,
          challengerBreakdown,
          opponentBreakdown,
          winnerId: row.winner_id,
        };
      }),
    );
  }
}

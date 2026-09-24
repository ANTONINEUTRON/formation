import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { randomBytes } from 'node:crypto';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { League } from '../core/db-types.js';
import type { AuthUser, LeagueDto, LeagueStandingDto } from '../domain/dto.js';
import type { SportMode } from '../domain/sport.js';
import { EntryScoringService } from '../scoring/entry-scoring.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { UsersService } from '../users/users.service.js';
import type { LineupSnapshot, SlotExits } from '../scoring/engine/types.js';

/** Durations a creator can pick, in hours. */
export const LEAGUE_DURATION_HOURS = [1, 6, 24, 72, 168] as const;

export interface CreateLeagueInput {
  name: string;
  mode: SportMode;
  visibility: 'public' | 'private';
  startsAt: Date;
  durationHours: number;
  /** 2 makes it a PvP duel; null leaves it open. */
  maxMembers: number | null;
  /** Username to invite straight away, for a PvP challenge. */
  invite?: string;
}

/**
 * Custom leagues, and PvP duels as a two-player case of the same thing.
 *
 * The creator picks when it starts and how long it runs. Until it starts,
 * people can join and change their teams freely. At `starts_at` every member's
 * lineup is locked into a snapshot; from then on substitutions affect only the
 * general league, never a running one. At `ends_at` it settles on points.
 */
@Injectable()
export class LeaguesService {
  private readonly logger = new Logger(LeaguesService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly scoring: EntryScoringService,
    private readonly users: UsersService,
    private readonly notifications: NotificationsService,
  ) {}

  async create(user: AuthUser, input: CreateLeagueInput): Promise<LeagueDto> {
    const name = input.name.trim();
    if (name.length < 3 || name.length > 40) {
      throw new BadRequestException('League name must be 3–40 characters');
    }
    if (!(LEAGUE_DURATION_HOURS as readonly number[]).includes(input.durationHours)) {
      throw new BadRequestException(
        `durationHours must be one of ${LEAGUE_DURATION_HOURS.join(', ')}`,
      );
    }
    if (input.startsAt.getTime() < this.clock.now() - 60_000) {
      throw new BadRequestException('Start time must be in the future');
    }

    const league = await this.db
      .insertInto('leagues')
      .values({
        name,
        creator_id: user.id,
        sport_mode: input.mode,
        visibility: input.visibility,
        join_code: randomBytes(4).toString('hex').toUpperCase(),
        starts_at: input.startsAt,
        ends_at: new Date(input.startsAt.getTime() + input.durationHours * 3_600_000),
        max_members: input.maxMembers,
      })
      .returningAll()
      .executeTakeFirstOrThrow();

    await this.addMember(league, user.id);
    if (input.invite) {
      // Accepts a wallet address or a username, like the old duel challenge.
      const opponent = await this.users.findByHandle(input.invite);
      if (opponent.id === user.id) throw new BadRequestException("You can't duel yourself");
      await this.addMember(league, opponent.id);
    }
    return this.toDto(league, user.id);
  }

  /** Public leagues still open to join, plus every league the user is in. */
  async list(user: AuthUser, mode: SportMode): Promise<LeagueDto[]> {
    const rows = await this.db
      .selectFrom('leagues')
      .selectAll('leagues')
      .leftJoin('league_members', (join) =>
        join
          .onRef('league_members.league_id', '=', 'leagues.id')
          .on('league_members.user_id', '=', user.id),
      )
      .where('leagues.sport_mode', '=', mode)
      .where((eb) =>
        eb.or([
          eb('league_members.user_id', 'is not', null),
          eb.and([
            eb('leagues.visibility', '=', 'public'),
            eb('leagues.status', '=', 'scheduled'),
          ]),
        ]),
      )
      .orderBy('leagues.starts_at')
      .limit(50)
      .execute();

    return Promise.all(rows.map((row) => this.toDto(row, user.id)));
  }

  async byId(user: AuthUser, id: string): Promise<LeagueDto> {
    return this.toDto(await this.get(id), user.id);
  }

  /** Joins by id (public) or by code (private). */
  async join(user: AuthUser, { id, code }: { id?: string; code?: string }): Promise<LeagueDto> {
    const league = code
      ? await this.db
          .selectFrom('leagues')
          .selectAll()
          .where('join_code', '=', code.trim().toUpperCase())
          .executeTakeFirst()
      : await this.get(id ?? '');
    if (!league) throw new NotFoundException('No league with that code');

    if (league.status !== 'scheduled') {
      throw new BadRequestException('This league has already started');
    }
    if (league.visibility === 'private' && !code) {
      throw new ForbiddenException('This league needs a join code');
    }
    if (league.max_members !== null) {
      const { count } = await this.memberCount(league.id);
      if (count >= league.max_members) {
        throw new BadRequestException('This league is full');
      }
    }

    await this.addMember(league, user.id);
    if (league.creator_id !== user.id) {
      const joiner = (await this.users.getMany([user.id])).get(user.id);
      await this.notifications.push({
        userId: league.creator_id,
        kind: 'league_joined',
        title: `${joiner?.username ?? 'A player'} joined ${league.name}`,
        body: 'Your league has a new member.',
        data: { leagueId: league.id },
      });
    }
    return this.toDto(league, user.id);
  }

  async leave(user: AuthUser, id: string): Promise<void> {
    const league = await this.get(id);
    if (league.status !== 'scheduled') {
      throw new BadRequestException('You cannot leave a league that has started');
    }
    await this.db
      .deleteFrom('league_members')
      .where('league_id', '=', id)
      .where('user_id', '=', user.id)
      .execute();
  }

  /** Opens leagues whose start has passed and settles those that have ended. */
  @Cron(CronExpression.EVERY_MINUTE)
  async processDue(): Promise<void> {
    const now = this.clock.date();
    const starting = await this.db
      .selectFrom('leagues')
      .selectAll()
      .where('status', '=', 'scheduled')
      .where('starts_at', '<=', now)
      .execute();
    for (const league of starting) {
      try {
        await this.open(league);
      } catch (e) {
        this.logger.warn(`Opening league ${league.id} failed: ${String(e)}`);
      }
    }

    const ending = await this.db
      .selectFrom('leagues')
      .selectAll()
      .where('status', '=', 'live')
      .where('ends_at', '<=', now)
      .execute();
    for (const league of ending) {
      try {
        await this.settle(league);
      } catch (e) {
        this.logger.warn(`Settling league ${league.id} failed: ${String(e)}`);
      }
    }
  }

  /** Locks every member's lineup and flips the league live. */
  async open(league: League): Promise<void> {
    const members = await this.membersOf(league.id);
    for (const member of members) {
      const snapshot = await this.scoring.lockLineup(
        member.user_id,
        member.wallet_address,
        league.sport_mode,
      );
      // An incomplete team simply doesn't score; they stay a member.
      if (!snapshot) continue;
      await this.db
        .insertInto('score_entries')
        .values({
          context: 'league',
          context_id: league.id,
          user_id: member.user_id,
          sport_mode: league.sport_mode,
          snapshot: JSON.stringify(snapshot),
        })
        .onConflict((oc) => oc.columns(['context', 'context_id', 'user_id']).doNothing())
        .execute();
    }
    const opened = await this.db
      .updateTable('leagues')
      .set({ status: 'live' })
      .where('id', '=', league.id)
      .where('status', '=', 'scheduled')
      .returning('id')
      .executeTakeFirst();
    if (!opened) return; // Another run opened it; don't notify twice.

    await this.notifications.pushMany(
      members.map((member) => ({
        userId: member.user_id,
        kind: 'league_started' as const,
        title: `${league.name} has started`,
        body: 'Lineups are locked for this league. Your general-league team keeps running as normal.',
        data: { leagueId: league.id },
      })),
    );
  }

  /** Demo control: settles a league by id without waiting for its end time. */
  async settleById(id: string): Promise<void> {
    const league = await this.get(id);
    if (league.status === 'scheduled') await this.open(league);
    await this.settle(await this.get(id));
  }

  /** Scores every locked lineup over the whole window and closes the league. */
  async settle(league: League): Promise<void> {
    const scores = await this.scoreMembers(league, new Date(league.ends_at).getTime(), true);
    await this.db.transaction().execute(async (trx) => {
      const claimed = await trx
        .updateTable('leagues')
        .set({ status: 'final' })
        .where('id', '=', league.id)
        .where('status', '=', 'live')
        .returning('id')
        .executeTakeFirst();
      if (!claimed) return; // Another run got there first.

      for (const { userId, points } of scores) {
        await trx
          .updateTable('score_entries')
          .set({ final_points: points, live_points: points, updated_at: this.clock.date() })
          .where('context', '=', 'league')
          .where('context_id', '=', league.id)
          .where('user_id', '=', userId)
          .execute();
      }
    });
    const ranked = [...scores].sort((a, b) => b.points - a.points);
    await this.notifications.pushMany(
      ranked.map((result, i) => ({
        userId: result.userId,
        kind: 'league_settled' as const,
        title: `${league.name} is done`,
        body:
          i === 0
            ? `You won with ${result.points} points.`
            : `You finished #${i + 1} of ${ranked.length} with ${result.points} points.`,
        data: { leagueId: league.id, rank: i + 1 },
      })),
    );
    this.logger.log(`Settled league ${league.name} (${scores.length} entries)`);
  }

  /**
   * Points for each member. Live leagues are scored up to now; settled ones
   * read the stored finals so the table never moves again.
   */
  private async scoreMembers(
    league: League,
    until: number,
    fresh = false,
  ): Promise<{ userId: string; points: number }[]> {
    const rows = await this.db
      .selectFrom('score_entries')
      .innerJoin('users', 'users.id', 'score_entries.user_id')
      .select([
        'score_entries.user_id as user_id',
        'score_entries.snapshot as snapshot',
        'score_entries.exits as exits',
        'score_entries.final_points as final_points',
        'users.wallet_address as wallet_address',
      ])
      .where('score_entries.context', '=', 'league')
      .where('score_entries.context_id', '=', league.id)
      .execute();

    const window = this.scoring.window(
      new Date(league.starts_at),
      new Date(Math.min(until, new Date(league.ends_at).getTime())),
    );
    const results: { userId: string; points: number }[] = [];

    for (const row of rows) {
      if (row.final_points !== null) {
        results.push({ userId: row.user_id, points: row.final_points });
        continue;
      }
      const snapshot = parse<LineupSnapshot>(row.snapshot);
      if (!snapshot) continue;
      const { breakdown } = await this.scoring.score(snapshot, row.wallet_address, window, {
        fresh,
        exits: parse<SlotExits>(row.exits) ?? {},
        at: window.end,
      });
      results.push({ userId: row.user_id, points: breakdown.total });
    }
    return results;
  }

  private async toDto(league: League, viewerId: string): Promise<LeagueDto> {
    const [{ count }, creator, member] = await Promise.all([
      this.memberCount(league.id),
      this.db
        .selectFrom('users')
        .select('username')
        .where('id', '=', league.creator_id)
        .executeTakeFirst(),
      this.db
        .selectFrom('league_members')
        .select('user_id')
        .where('league_id', '=', league.id)
        .where('user_id', '=', viewerId)
        .executeTakeFirst(),
    ]);

    const joined = member !== undefined;
    const full = league.max_members !== null && count >= league.max_members;

    return {
      id: league.id,
      name: league.name,
      mode: league.sport_mode,
      visibility: league.visibility,
      joinCode: league.join_code,
      startsAt: new Date(league.starts_at).toISOString(),
      endsAt: new Date(league.ends_at).toISOString(),
      status: league.status,
      maxMembers: league.max_members,
      memberCount: count,
      createdBy: creator?.username ?? 'unknown',
      joined,
      joinable: league.status === 'scheduled' && !joined && !full,
      standings:
        league.status === 'scheduled' ? [] : await this.standings(league, viewerId),
    };
  }

  private async standings(league: League, viewerId: string): Promise<LeagueStandingDto[]> {
    const scores = await this.scoreMembers(league, this.clock.now());
    const members = await this.membersOf(league.id);
    const byId = new Map(members.map((m) => [m.user_id, m]));

    return scores
      .sort((a, b) => b.points - a.points)
      .map((score, i) => ({
        rank: i + 1,
        userId: score.userId,
        username: byId.get(score.userId)?.username ?? 'unknown',
        walletAddress: byId.get(score.userId)?.wallet_address ?? '',
        points: score.points,
        isCurrentUser: score.userId === viewerId,
      }));
  }

  private async addMember(league: League, userId: string): Promise<void> {
    await this.db
      .insertInto('league_members')
      .values({ league_id: league.id, user_id: userId })
      .onConflict((oc) => oc.columns(['league_id', 'user_id']).doNothing())
      .execute();
  }

  private async memberCount(leagueId: string): Promise<{ count: number }> {
    const row = await this.db
      .selectFrom('league_members')
      .select((eb) => eb.fn.countAll<string>().as('count'))
      .where('league_id', '=', leagueId)
      .executeTakeFirst();
    return { count: Number(row?.count ?? 0) };
  }

  private async membersOf(leagueId: string) {
    return this.db
      .selectFrom('league_members')
      .innerJoin('users', 'users.id', 'league_members.user_id')
      .select([
        'league_members.user_id as user_id',
        'users.username as username',
        'users.wallet_address as wallet_address',
      ])
      .where('league_members.league_id', '=', leagueId)
      .execute();
  }

  private async get(id: string): Promise<League> {
    const row = await this.db
      .selectFrom('leagues')
      .selectAll()
      .where('id', '=', id)
      .executeTakeFirst();
    if (!row) throw new NotFoundException('League not found');
    return row;
  }
}

function parse<T>(value: unknown): T | undefined {
  if (value === null || value === undefined) return undefined;
  return typeof value === 'string' ? (JSON.parse(value) as T) : (value as T);
}

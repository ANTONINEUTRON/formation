import { BadRequestException, ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { sql } from 'kysely';
import { CUSTOM_ID } from '../assistant/avatars.js';
import { CHARACTERS, characterById } from '../assistant/characters.js';
import { CreditsService } from '../assistant/credits.service.js';
import { SessionService } from '../auth/session.service.js';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { CALENDAR } from '../domain/calendar.js';
import type { GameCalendar } from '../domain/calendar.js';
import { SPORT_MODES } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { LedgerService } from '../scoring/ledger.service.js';
import { defaultUsername } from '../users/users.service.js';
import { AdminAuditService, UUID } from './audit.service.js';
import { AdminHoldingsService } from './holdings.service.js';

const PAGE_SIZE = 25;
const HOUR = 3_600_000;
const DAY = 24 * HOUR;
/** Grants and clawbacks larger than this are refused outright. */
const MAX_CREDIT_ADJUST = 10_000;

export interface ManagersQuery {
  q?: string;
  signedUp?: string;
  active?: string;
  holds?: string;
  sport?: string;
  status?: string;
  showSeeds?: string;
  sort?: string;
  dir?: string;
  page?: string;
}

export interface ManagerRowDto {
  id: string;
  username: string;
  walletAddress: string;
  createdAt: string;
  lastActiveAt: string | null;
  sports: SportMode[];
  isSeed: boolean;
  suspended: boolean;
  deleted: boolean;
  holdingsUsd: number | null;
  holdingsReadAt: string | null;
}

export interface ManagersPageDto {
  rows: ManagerRowDto[];
  matching: number;
  total: number;
  page: number;
  pageSize: number;
}

const WINDOWS: Record<string, number> = { '24h': DAY, '7d': 7 * DAY, '30d': 30 * DAY };
const SORTS = {
  username: 'users.username',
  createdAt: 'users.created_at',
  lastActiveAt: 'users.last_seen_at',
  holdingsUsd: 'wallet_reads.total_usd',
} as const;

/**
 * Managers, as the admin sees them: the searchable list (ADMIN_PLAN.md
 * Phase 5's users table, which Phase 2 builds on), each Manager's full
 * picture, and every moderation action, each recorded in the audit log in
 * the same transaction as the change.
 */
@Injectable()
export class AdminManagersService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(CALENDAR) private readonly calendar: GameCalendar,
    private readonly audit: AdminAuditService,
    private readonly ledger: LedgerService,
    private readonly credits: CreditsService,
    private readonly sessions: SessionService,
    private readonly holdings: AdminHoldingsService,
  ) {}

  // ── List ───────────────────────────────────────────────────────────────────

  /** Search, filters and paging. Reads the database only, never the RPC. */
  async list(query: ManagersQuery): Promise<ManagersPageDto> {
    const now = this.clock.now();
    const page = Math.max(1, Number(query.page) || 1);
    const q = (query.q ?? '').trim();
    const status = query.status ?? 'all';

    let base = this.db
      .selectFrom('users')
      .leftJoin('wallet_reads', 'wallet_reads.user_id', 'users.id');

    if (query.showSeeds !== 'true') base = base.where('users.is_seed', '=', false);
    if (status === 'deleted') base = base.where('users.deleted_at', 'is not', null);
    else base = base.where('users.deleted_at', 'is', null);
    if (status === 'suspended') base = base.where('users.suspended_at', 'is not', null);
    if (status === 'active') base = base.where('users.suspended_at', 'is', null);

    if (q) {
      const like = `%${q.replace(/[%_\\]/g, (c) => `\\${c}`)}%`;
      base = base.where((eb) =>
        eb.or([
          eb('users.username', 'ilike', like),
          eb('users.wallet_address', 'ilike', like),
          ...(UUID.test(q) ? [eb('users.id', '=', q)] : []),
        ]),
      );
    }
    const signedUp = WINDOWS[query.signedUp ?? ''];
    if (signedUp) base = base.where('users.created_at', '>=', new Date(now - signedUp));
    const active = query.active === '24h' || query.active === '7d' ? WINDOWS[query.active] : undefined;
    if (active) base = base.where('users.last_seen_at', '>=', new Date(now - active));
    if (query.holds === 'has') base = base.where('wallet_reads.total_usd', '>', 0);
    if (query.holds === 'none') base = base.where('wallet_reads.total_usd', '=', 0);
    if (query.sport && (SPORT_MODES as readonly string[]).includes(query.sport)) {
      base = base.where((eb) =>
        eb.exists(
          eb
            .selectFrom('rosters')
            .select('rosters.id')
            .whereRef('rosters.user_id', '=', 'users.id')
            .where('rosters.sport_mode', '=', query.sport as SportMode),
        ),
      );
    }

    const sortColumn = SORTS[(query.sort ?? 'createdAt') as keyof typeof SORTS] ?? SORTS.createdAt;
    const dir = query.dir === 'asc' ? 'asc' : 'desc';

    const [rows, matching, total] = await Promise.all([
      base
        .select([
          'users.id as id',
          'users.username as username',
          'users.wallet_address as wallet_address',
          'users.created_at as created_at',
          'users.last_seen_at as last_seen_at',
          'users.is_seed as is_seed',
          'users.suspended_at as suspended_at',
          'users.deleted_at as deleted_at',
          'wallet_reads.total_usd as total_usd',
          'wallet_reads.read_at as read_at',
        ])
        .select((eb) =>
          eb
            .selectFrom('rosters')
            .select(sql<SportMode[]>`coalesce(array_agg(distinct rosters.sport_mode), '{}')`.as('sports'))
            .whereRef('rosters.user_id', '=', 'users.id')
            .as('sports'),
        )
        .orderBy(sql.ref(sortColumn), sql.raw(`${dir} nulls last`))
        .orderBy('users.id')
        .limit(PAGE_SIZE)
        .offset((page - 1) * PAGE_SIZE)
        .execute(),
      base.select((eb) => eb.fn.countAll<string>().as('n')).executeTakeFirstOrThrow(),
      this.db
        .selectFrom('users')
        .select((eb) => eb.fn.countAll<string>().as('n'))
        .where('is_seed', '=', false)
        .where('deleted_at', 'is', null)
        .executeTakeFirstOrThrow(),
    ]);

    return {
      rows: rows.map((r) => ({
        id: r.id,
        username: r.username,
        walletAddress: r.wallet_address,
        createdAt: new Date(r.created_at).toISOString(),
        lastActiveAt: r.last_seen_at ? new Date(r.last_seen_at).toISOString() : null,
        sports: sportsArray(r.sports),
        isSeed: r.is_seed,
        suspended: r.suspended_at !== null,
        deleted: r.deleted_at !== null,
        holdingsUsd: r.total_usd === null ? null : Number(r.total_usd),
        holdingsReadAt: r.read_at ? new Date(r.read_at).toISOString() : null,
      })),
      matching: Number(matching.n),
      total: Number(total.n),
      page,
      pageSize: PAGE_SIZE,
    };
  }

  // ── Profile ────────────────────────────────────────────────────────────────

  async detail(id: string) {
    const user = await this.find(id);
    const now = this.clock.now();
    const week = this.calendar.weekAt(now);
    const season = this.calendar.seasonAt(now);

    const [credits, creditMoves, devices, push, scores, weekRows, seasonRows, ledger, holdings, actions, rosters, avatar, profile] =
      await Promise.all([
        this.db.selectFrom('assistant_credits').select('balance').where('user_id', '=', id).executeTakeFirst(),
        this.db
          .selectFrom('credit_ledger')
          .select(['delta', 'balance_after', 'reason', 'ref', 'created_at'])
          .where('user_id', '=', id)
          .orderBy('id', 'desc')
          .limit(20)
          .execute(),
        this.db
          .selectFrom('device_tokens')
          .select(['platform', 'created_at', 'last_seen_at'])
          .where('user_id', '=', id)
          .orderBy('last_seen_at', 'desc')
          .execute(),
        this.db.selectFrom('push_preferences').selectAll().where('user_id', '=', id).executeTakeFirst(),
        this.db.selectFrom('classic_scores').select(['sport_mode', 'total_points', 'streak']).where('user_id', '=', id).execute(),
        this.pointsBetween(id, week.kickOff, new Date(now)),
        this.pointsBetween(id, season.startsAt, new Date(now)),
        this.db
          .selectFrom('points_ledger')
          .select(['id', 'sport_mode', 'kind', 'points', 'detail', 'at', 'season'])
          .where('user_id', '=', id)
          .orderBy('at', 'desc')
          .limit(100 * SPORT_MODES.length)
          .execute(),
        this.holdings.holdingsOf(id),
        this.audit.list({ userId: id, limit: '50' }),
        this.db.selectFrom('rosters').select('sport_mode').where('user_id', '=', id).execute(),
        this.db
          .selectFrom('assistant_avatars')
          .select((eb) => eb.fn.countAll<string>().as('n'))
          .where('user_id', '=', id)
          .executeTakeFirstOrThrow(),
        this.db.selectFrom('assistant_profiles').select(['character_id', 'custom_name']).where('user_id', '=', id).executeTakeFirst(),
      ]);

    // The last 100 rows per sport.
    const perSport = new Map<string, number>();
    const ledgerRows = ledger.filter((row) => {
      const n = (perSport.get(row.sport_mode) ?? 0) + 1;
      perSport.set(row.sport_mode, n);
      return n <= 100;
    });

    return {
      id: user.id,
      username: user.username,
      walletAddress: user.wallet_address,
      bio: user.bio,
      email: user.email,
      createdAt: new Date(user.created_at).toISOString(),
      lastActiveAt: user.last_seen_at ? new Date(user.last_seen_at).toISOString() : null,
      isSeed: user.is_seed,
      suspendedAt: user.suspended_at ? new Date(user.suspended_at).toISOString() : null,
      suspendedReason: user.suspended_reason,
      deletedAt: user.deleted_at ? new Date(user.deleted_at).toISOString() : null,
      sports: rosters.map((r) => r.sport_mode),
      assistant: {
        character: profile?.character_id ?? null,
        customName: profile?.custom_name ?? null,
        customAvatar: Number(avatar.n) > 0,
      },
      credits: {
        balance: credits?.balance ?? null,
        recent: creditMoves.map((m) => ({
          delta: m.delta,
          balanceAfter: m.balance_after,
          reason: m.reason,
          ref: m.ref,
          at: new Date(m.created_at as unknown as Date).toISOString(),
        })),
      },
      devices: devices.map((d) => ({
        platform: d.platform,
        createdAt: new Date(d.created_at).toISOString(),
        lastSeenAt: new Date(d.last_seen_at).toISOString(),
      })),
      push: push
        ? {
            categories: push.categories,
            quietHours: push.quiet_enabled ? { start: push.quiet_start, end: push.quiet_end } : null,
            timeZone: push.time_zone,
          }
        : null,
      scores: SPORT_MODES.map((mode) => {
        const row = scores.find((s) => s.sport_mode === mode);
        return {
          mode,
          seasonTotal: row?.total_points ?? 0,
          streak: row?.streak ?? 0,
          thisWeek: weekRows.get(mode) ?? 0,
          thisSeasonLedger: seasonRows.get(mode) ?? 0,
        };
      }),
      week: { number: week.number, season: week.season, kickOff: week.kickOff.toISOString() },
      ledger: ledgerRows.map((row) => ({
        id: row.id,
        mode: row.sport_mode,
        kind: row.kind,
        points: Number(row.points),
        detail: row.detail,
        at: new Date(row.at).toISOString(),
        season: row.season,
      })),
      holdings,
      actions,
      correctionLimit: this.config.adminCorrectionLimit,
    };
  }

  private async pointsBetween(userId: string, from: Date, to: Date): Promise<Map<string, number>> {
    const rows = await this.db
      .selectFrom('points_ledger')
      .select((eb) => ['sport_mode', eb.fn.sum<string>('points').as('points')])
      .where('user_id', '=', userId)
      .where('at', '>=', from)
      .where('at', '<=', to)
      .groupBy('sport_mode')
      .execute();
    return new Map(rows.map((r) => [r.sport_mode, Math.round(Number(r.points) * 10) / 10]));
  }

  private async find(id: string) {
    if (!UUID.test(id)) throw new NotFoundException('No such Manager');
    const user = await this.db.selectFrom('users').selectAll().where('id', '=', id).executeTakeFirst();
    if (!user) throw new NotFoundException('No such Manager');
    return user;
  }

  private async findLive(id: string) {
    const user = await this.find(id);
    if (user.deleted_at) throw new ConflictException('This account has been deleted');
    return user;
  }

  // ── Moderation ─────────────────────────────────────────────────────────────

  async resetUsername(admin: string, id: string, reason: string) {
    const user = await this.findLive(id);
    const next = await this.freeUsername(defaultUsername(user.wallet_address));
    return this.audit.run(
      { admin, action: 'user.username_reset', targetUserId: id, reason },
      async (trx) => {
        await trx.updateTable('users').set({ username: next }).where('id', '=', id).execute();
        return { result: { username: next }, detail: { before: user.username, after: next } };
      },
    );
  }

  /** The wallet-derived name, or one with a numeric suffix if someone has it. */
  private async freeUsername(base: string): Promise<string> {
    for (let i = 0; i < 50; i++) {
      const candidate = i === 0 ? base : `${base.slice(0, 16)}_${i}`;
      const taken = await this.db
        .selectFrom('users')
        .select('id')
        .where((eb) => eb(eb.fn('lower', ['username']), '=', candidate.toLowerCase()))
        .executeTakeFirst();
      if (!taken) return candidate;
    }
    throw new ConflictException('Could not find a free username');
  }

  async clearBio(admin: string, id: string, reason: string) {
    const user = await this.findLive(id);
    return this.audit.run({ admin, action: 'user.bio_clear', targetUserId: id, reason }, async (trx) => {
      await trx.updateTable('users').set({ bio: null }).where('id', '=', id).execute();
      // The text itself isn't kept: it may be why it was removed.
      return { result: { cleared: true }, detail: { hadBio: user.bio !== null } };
    });
  }

  /** Removes a custom Assistant Manager drawing; they fall back to its preset. */
  async deleteAvatar(admin: string, id: string, reason: string) {
    await this.findLive(id);
    return this.audit.run({ admin, action: 'user.avatar_delete', targetUserId: id, reason }, async (trx) => {
      const removed = await trx.deleteFrom('assistant_avatars').where('user_id', '=', id).executeTakeFirst();
      const profile = await trx
        .selectFrom('assistant_profiles')
        .select(['character_id', 'personality'])
        .where('user_id', '=', id)
        .executeTakeFirst();
      if (profile?.character_id === CUSTOM_ID) {
        const preset = characterById(profile.personality) ?? CHARACTERS[0];
        await trx
          .updateTable('assistant_profiles')
          .set({ character_id: preset.id, custom_name: null, updated_at: this.clock.date() })
          .where('user_id', '=', id)
          .execute();
      }
      return {
        result: { removed: Number(removed.numDeletedRows) },
        detail: { poses: Number(removed.numDeletedRows) },
      };
    });
  }

  async suspend(admin: string, id: string, reason: string) {
    const user = await this.findLive(id);
    if (user.suspended_at) throw new ConflictException('Already suspended');
    const out = await this.audit.run({ admin, action: 'user.suspend', targetUserId: id, reason }, async (trx) => {
      await trx
        .updateTable('users')
        .set({ suspended_at: this.clock.date(), suspended_reason: reason })
        .where('id', '=', id)
        .execute();
      return { result: { suspended: true } };
    });
    this.sessions.forget(id);
    return out;
  }

  async unsuspend(admin: string, id: string, reason: string) {
    const user = await this.findLive(id);
    if (!user.suspended_at) throw new ConflictException('Not suspended');
    const out = await this.audit.run({ admin, action: 'user.unsuspend', targetUserId: id, reason }, async (trx) => {
      await trx
        .updateTable('users')
        .set({ suspended_at: null, suspended_reason: null })
        .where('id', '=', id)
        .execute();
      return {
        result: { suspended: false },
        detail: { suspendedFor: duration(this.clock.now() - new Date(user.suspended_at!).getTime()) },
      };
    });
    this.sessions.forget(id);
    return out;
  }

  // ── Score corrections ──────────────────────────────────────────────────────

  /**
   * Adds a `correction` row through the ledger, so totals, boards and season
   * results update the usual way. Rows are never deleted: undoing one is an
   * equal and opposite correction.
   */
  async correct(
    admin: string,
    id: string,
    body: { mode?: unknown; points?: unknown; reason: string; confirmLarge?: unknown },
  ) {
    await this.findLive(id);
    const mode = SPORT_MODES.find((m) => m === body.mode);
    if (!mode) throw new BadRequestException('Pick football, basketball or american_football');
    const points = Math.round(Number(body.points) * 10) / 10;
    if (!Number.isFinite(points) || points === 0) throw new BadRequestException('Points must be a non-zero number');
    const limit = this.config.adminCorrectionLimit;
    if (Math.abs(points) > limit && body.confirmLarge !== true) {
      throw new BadRequestException(`Corrections over ±${limit} points need a second confirmation`);
    }

    const before = await this.seasonTotal(id, mode);
    return this.audit.run({ admin, action: 'score.correct', targetUserId: id, reason: body.reason }, async (trx) => {
      await this.ledger.award(id, mode, 'correction', points, this.clock.now(), { reason: body.reason, admin }, trx);
      const after = await this.seasonTotal(id, mode, trx);
      return { result: { mode, points, before, after }, detail: { mode, points, before, after } };
    });
  }

  private async seasonTotal(userId: string, mode: SportMode, db: Db = this.db): Promise<number> {
    const row = await db
      .selectFrom('classic_scores')
      .select('total_points')
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    return row?.total_points ?? 0;
  }

  // ── Credits ────────────────────────────────────────────────────────────────

  /** Positive grants, negative claws back; never below 0. */
  async adjustCredits(admin: string, id: string, body: { credits?: unknown; reason: string }) {
    await this.findLive(id);
    const credits = Number(body.credits);
    if (!Number.isInteger(credits) || credits === 0) throw new BadRequestException('Credits must be a non-zero whole number');
    if (Math.abs(credits) > MAX_CREDIT_ADJUST) {
      throw new BadRequestException(`At most ${MAX_CREDIT_ADJUST} credits at a time`);
    }
    return this.audit.run(
      { admin, action: credits > 0 ? 'credits.grant' : 'credits.clawback', targetUserId: id, reason: body.reason },
      async (trx) => {
        const moved = await this.credits.adjust(trx, id, credits);
        return { result: moved, detail: { requested: credits, ...moved } };
      },
    );
  }

  // ── Deletion ───────────────────────────────────────────────────────────────

  /**
   * Deletes an account on request (the Privacy Policy's promise). Personal
   * data and everything that only serves the Manager goes; the ledger,
   * season results, weekly stats and league fixtures stay, under an
   * anonymous name, so past league tables still add up.
   */
  async deleteAccount(admin: string, id: string, body: { reason: string; confirmUsername?: unknown }) {
    const user = await this.findLive(id);
    if (body.confirmUsername !== user.username) {
      throw new BadRequestException('Type the current username to confirm');
    }
    const tombstone = `deleted-${id.replace(/-/g, '').slice(0, 6)}`;

    const out = await this.audit.run(
      // The record holds the id and the reason, nothing personal.
      { admin, action: 'user.delete', targetUserId: id, reason: body.reason },
      async (trx) => {
        const rosterIds = trx.selectFrom('rosters').select('id').where('user_id', '=', id);
        await trx.deleteFrom('roster_slots').where('roster_id', 'in', rosterIds).execute();
        for (const table of [
          'rosters',
          'general_entries',
          'live_events',
          'daily_substitutions',
          'device_tokens',
          'push_preferences',
          'notifications',
          'assistant_profiles',
          'assistant_avatars',
          'assistant_credits',
          'feedback',
          'wallet_holdings',
          'wallet_reads',
        ] as const) {
          await trx.deleteFrom(table).where('user_id', '=', id).execute();
        }
        // Purchases stay as a financial record (they're on chain anyway), so
        // only the quotes they don't point at go.
        await trx
          .deleteFrom('credit_quotes')
          .where('user_id', '=', id)
          .where((eb) => eb.not(eb.exists(eb.selectFrom('credit_purchases').select('signature').whereRef('credit_purchases.quote_id', '=', 'credit_quotes.id'))))
          .execute();
        await trx
          .deleteFrom('follows')
          .where((eb) => eb.or([eb('follower_id', '=', id), eb('followee_id', '=', id)]))
          .execute();
        await trx
          .updateTable('users')
          .set({
            username: tombstone,
            bio: null,
            email: null,
            // Unique and not a key, so the real wallet can sign up afresh.
            wallet_address: `deleted:${id}`,
            deleted_at: this.clock.date(),
            suspended_at: null,
            suspended_reason: null,
            last_seen_at: null,
          })
          .where('id', '=', id)
          .execute();
        return { result: { deleted: true, username: tombstone } };
      },
    );
    this.sessions.forget(id);
    return out;
  }
}

/** pg returns text[] as an array, but an enum array may come back as "{a,b}". */
function sportsArray(value: unknown): SportMode[] {
  if (Array.isArray(value)) return value as SportMode[];
  if (typeof value === 'string') {
    return value
      .replace(/[{}]/g, '')
      .split(',')
      .filter((v): v is SportMode => (SPORT_MODES as readonly string[]).includes(v));
  }
  return [];
}

function duration(ms: number): string {
  return ms < DAY ? `${Math.max(1, Math.round(ms / HOUR))} h` : `${Math.round(ms / DAY)} d`;
}

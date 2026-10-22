import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { localDay } from '../domain/visit-streak.js';

/** How long a user's suspended / deleted state is trusted before re-reading it. */
const STATE_TTL_MS = 60_000;
/** last_seen_at is written at most this often per user. */
const SEEN_EVERY_MS = 60 * 60_000;

interface CachedState {
  blocked: boolean;
  checkedAt: number;
  seenAt: number;
  /** Their time zone, for what "today" means. */
  zone: string;
  /** The last day their visit was counted, in that zone. */
  visitDay: string | null;
}

/** Called once per user per day on their first request that day. */
export type VisitHook = (userId: string, day: string) => Promise<void>;

/**
 * What every authenticated request needs beyond a valid token: whether the
 * account has since been suspended or deleted, and a "last seen" for the
 * admin's active filter.
 *
 * Bearer tokens live for 30 days, so refusing sign-in alone would leave a
 * suspended Manager playing on the token they already have. Both answers are
 * cached briefly so this isn't a query per request; a suspension made from
 * the admin clears the cache entry straight away.
 */
@Injectable()
export class SessionService {
  private readonly cache = new Map<string, CachedState>();
  private visitHook: VisitHook | null = null;

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  /** False when the account can no longer be used. Touches last_seen_at hourly. */
  async allow(userId: string): Promise<boolean> {
    const now = this.clock.now();
    let state = this.cache.get(userId);

    if (!state || now - state.checkedAt > STATE_TTL_MS) {
      const row = await this.db
        .selectFrom('users')
        .leftJoin('push_preferences', 'push_preferences.user_id', 'users.id')
        .select([
          'users.suspended_at',
          'users.deleted_at',
          'users.last_seen_at',
          'push_preferences.time_zone',
          // pg turns a date into a local-midnight Date; text keeps the day itself.
          sql<string | null>`to_char(users.last_visit_day, 'YYYY-MM-DD')`.as('last_visit_day'),
        ])
        .where('users.id', '=', userId)
        .executeTakeFirst();
      state = {
        blocked: !row || row.suspended_at !== null || row.deleted_at !== null,
        checkedAt: now,
        seenAt: row?.last_seen_at ? new Date(row.last_seen_at).getTime() : 0,
        zone: row?.time_zone ?? 'UTC',
        // Keep a day already counted this process, in case the row lags it.
        visitDay: maxDay(row?.last_visit_day ?? null, state?.visitDay ?? null),
      };
      this.cache.set(userId, state);
    }
    if (state.blocked) return false;

    const today = localDay(now, state.zone);
    if (state.visitDay !== today && this.visitHook) {
      state.visitDay = today;
      // A streak is never worth failing the request over.
      await this.visitHook(userId, today).catch(() => undefined);
    }

    if (now - state.seenAt > SEEN_EVERY_MS) {
      state.seenAt = now;
      // Guarded in SQL too, so several server instances don't each write it.
      await this.db
        .updateTable('users')
        .set({ last_seen_at: new Date(now) })
        .where('id', '=', userId)
        .where((eb) =>
          eb.or([
            eb('last_seen_at', 'is', null),
            eb('last_seen_at', '<', sql<Date>`${new Date(now - SEEN_EVERY_MS)}`),
          ]),
        )
        .execute();
    }
    return true;
  }

  /** Registers what happens on a Manager's first visit of the day (the streak). */
  onVisit(hook: VisitHook): void {
    this.visitHook = hook;
  }

  /** Records a sign-in as being seen, outside the hourly throttle. */
  async signedIn(userId: string): Promise<void> {
    const now = this.clock.now();
    await this.db.updateTable('users').set({ last_seen_at: new Date(now) }).where('id', '=', userId).execute();
    // Re-read on the next request, which also counts today's visit.
    this.cache.delete(userId);
  }

  /** Drops the cached state, so a suspension or deletion applies on the next request. */
  forget(userId: string): void {
    this.cache.delete(userId);
  }
}

/** The later of two YYYY-MM-DD days. */
function maxDay(a: string | null, b: string | null): string | null {
  if (a === null) return b;
  if (b === null) return a;
  return a > b ? a : b;
}

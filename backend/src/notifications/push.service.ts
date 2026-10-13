import { BadRequestException, Inject, Injectable, Logger } from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { NotificationKind } from '../core/db-types.js';
import type { PushSettingsDto } from '../domain/dto.js';
import { PUSH_SENDER } from './fcm.js';
import type { PushSender } from './fcm.js';
import {
  categoryOf,
  DAILY_PUSH_BUDGET,
  isQuiet,
  isValidTimeZone,
  localMinutes,
  PUSH_CATEGORY_NAMES,
} from './push-rules.js';
import type { PushCategory } from './push-rules.js';

export interface Pushable {
  userId: string;
  kind: NotificationKind;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

const PLATFORMS = ['android', 'ios', 'web'] as const;
const DAY = 86_400_000;

/**
 * Pushes notifications to players' devices (SCORING_PLAN.md Phase 4). It
 * never decides *what* to say: NotificationsService calls it with whatever
 * it just wrote to the inbox, and this decides whether to push it, honouring
 * each player's categories, quiet hours and a daily budget.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(PUSH_SENDER) private readonly sender: PushSender,
  ) {}

  /** Pushes what the guardrails allow. Never throws into the caller. */
  async deliver(notifications: Pushable[]): Promise<number> {
    if (!this.sender.enabled || notifications.length === 0) return 0;
    try {
      return await this.deliverOrThrow(notifications);
    } catch (e) {
      this.logger.warn(`Push delivery failed: ${String(e)}`);
      return 0;
    }
  }

  private async deliverOrThrow(notifications: Pushable[]): Promise<number> {
    const now = this.clock.now();
    const userIds = [...new Set(notifications.map((n) => n.userId))];
    const tokens = await this.db
      .selectFrom('device_tokens')
      .select(['token', 'user_id'])
      .where('user_id', 'in', userIds)
      .execute();
    if (tokens.length === 0) return 0;

    const [prefs, recent] = await Promise.all([
      this.db.selectFrom('push_preferences').selectAll().where('user_id', 'in', userIds).execute(),
      this.db
        .selectFrom('push_log')
        .select((eb) => ['user_id', eb.fn.countAll<string>().as('count')])
        .where('user_id', 'in', userIds)
        .where('sent_at', '>', new Date(now - DAY))
        .groupBy('user_id')
        .execute(),
    ]);
    const prefsOf = new Map(prefs.map((p) => [p.user_id, p]));
    const used = new Map(recent.map((r) => [r.user_id, Number(r.count)]));
    const devicesOf = new Map<string, string[]>();
    for (const t of tokens) devicesOf.set(t.user_id, [...(devicesOf.get(t.user_id) ?? []), t.token]);

    let sent = 0;
    for (const n of notifications) {
      const devices = devicesOf.get(n.userId);
      if (!devices || devices.length === 0) continue;
      const pref = prefsOf.get(n.userId);
      const categories = (pref?.categories ?? {}) as Record<string, boolean>;
      if (categories[categoryOf(n.kind)] === false) continue;
      if (
        (pref?.quiet_enabled ?? true) &&
        isQuiet(
          localMinutes(now, pref?.time_zone ?? 'UTC'),
          pref?.quiet_start ?? 22 * 60,
          pref?.quiet_end ?? 8 * 60,
        )
      ) {
        continue;
      }
      if ((used.get(n.userId) ?? 0) >= DAILY_PUSH_BUDGET) continue;

      const data = Object.fromEntries(
        Object.entries({ ...n.data, kind: n.kind }).map(([k, v]) => [
          k,
          typeof v === 'string' ? v : JSON.stringify(v),
        ]),
      );
      let delivered = false;
      for (const token of devices) {
        const result = await this.sender.send(token, { title: n.title, body: n.body, data });
        if (result === 'sent') delivered = true;
        if (result === 'invalid_token') {
          await this.db.deleteFrom('device_tokens').where('token', '=', token).execute();
          devicesOf.set(n.userId, (devicesOf.get(n.userId) ?? []).filter((t) => t !== token));
        }
      }
      if (delivered) {
        sent++;
        used.set(n.userId, (used.get(n.userId) ?? 0) + 1);
        await this.db
          .insertInto('push_log')
          .values({ user_id: n.userId, kind: n.kind, sent_at: new Date(now) })
          .execute();
      }
    }
    return sent;
  }

  /** Registers (or moves) a device to [userId]. */
  async registerDevice(
    userId: string,
    { token, platform, timeZone }: { token?: unknown; platform?: unknown; timeZone?: unknown },
  ): Promise<void> {
    if (typeof token !== 'string' || token.length < 10 || token.length > 4096) {
      throw new BadRequestException('A device token is required');
    }
    if (typeof platform !== 'string' || !(PLATFORMS as readonly string[]).includes(platform)) {
      throw new BadRequestException(`platform must be one of ${PLATFORMS.join(', ')}`);
    }
    const now = this.clock.date();
    await this.db
      .insertInto('device_tokens')
      .values({
        token,
        user_id: userId,
        platform: platform as (typeof PLATFORMS)[number],
        created_at: now,
        last_seen_at: now,
      })
      .onConflict((oc) => oc.column('token').doUpdateSet({ user_id: userId, last_seen_at: now }))
      .execute();
    if (typeof timeZone === 'string' && isValidTimeZone(timeZone)) {
      await this.saveSettings(userId, { timeZone });
    }
  }

  async unregisterDevice(userId: string, token: string): Promise<void> {
    await this.db
      .deleteFrom('device_tokens')
      .where('token', '=', token)
      .where('user_id', '=', userId)
      .execute();
  }

  async settings(userId: string): Promise<PushSettingsDto> {
    const [pref, devices] = await Promise.all([
      this.db.selectFrom('push_preferences').selectAll().where('user_id', '=', userId).executeTakeFirst(),
      this.db
        .selectFrom('device_tokens')
        .select((eb) => eb.fn.countAll<string>().as('count'))
        .where('user_id', '=', userId)
        .executeTakeFirst(),
    ]);
    const categories = (pref?.categories ?? {}) as Record<string, boolean>;
    return {
      available: this.sender.enabled,
      devices: Number(devices?.count ?? 0),
      categories: Object.fromEntries(
        PUSH_CATEGORY_NAMES.map((c) => [c, categories[c] !== false]),
      ) as Record<PushCategory, boolean>,
      quietEnabled: pref?.quiet_enabled ?? true,
      quietStart: pref?.quiet_start ?? 22 * 60,
      quietEnd: pref?.quiet_end ?? 8 * 60,
      timeZone: pref?.time_zone ?? 'UTC',
      dailyBudget: DAILY_PUSH_BUDGET,
    };
  }

  /** Updates whichever settings [body] carries. */
  async saveSettings(userId: string, body: Record<string, unknown>): Promise<PushSettingsDto> {
    const current = await this.settings(userId);
    const minutes = (value: unknown, field: string) => {
      if (value === undefined) return undefined;
      if (typeof value !== 'number' || !Number.isInteger(value) || value < 0 || value >= 1440) {
        throw new BadRequestException(`${field} must be minutes after midnight (0–1439)`);
      }
      return value;
    };
    const categories = { ...current.categories };
    if (body.categories !== undefined) {
      if (typeof body.categories !== 'object' || body.categories === null) {
        throw new BadRequestException('categories must be an object');
      }
      for (const [name, on] of Object.entries(body.categories)) {
        if (!(PUSH_CATEGORY_NAMES as string[]).includes(name) || typeof on !== 'boolean') {
          throw new BadRequestException(`Unknown push category: ${name}`);
        }
        categories[name as PushCategory] = on;
      }
    }
    if (body.timeZone !== undefined && (typeof body.timeZone !== 'string' || !isValidTimeZone(body.timeZone))) {
      throw new BadRequestException('timeZone must be an IANA zone such as Africa/Lagos');
    }
    if (body.quietEnabled !== undefined && typeof body.quietEnabled !== 'boolean') {
      throw new BadRequestException('quietEnabled must be true or false');
    }

    const values = {
      categories: JSON.stringify(categories),
      quiet_enabled: (body.quietEnabled as boolean | undefined) ?? current.quietEnabled,
      quiet_start: minutes(body.quietStart, 'quietStart') ?? current.quietStart,
      quiet_end: minutes(body.quietEnd, 'quietEnd') ?? current.quietEnd,
      time_zone: (body.timeZone as string | undefined) ?? current.timeZone,
      updated_at: this.clock.date(),
    };
    await this.db
      .insertInto('push_preferences')
      .values({ user_id: userId, ...values })
      .onConflict((oc) => oc.column('user_id').doUpdateSet(values))
      .execute();
    return this.settings(userId);
  }
}

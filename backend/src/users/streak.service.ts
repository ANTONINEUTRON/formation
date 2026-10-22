import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';
import { sql } from 'kysely';
import { SessionService } from '../auth/session.service.js';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { dayBefore, isMilestone, localDay } from '../domain/visit-streak.js';
import { NotificationsService } from '../notifications/notifications.service.js';

/** Local hour from which a streak that hasn't been kept today gets its reminder. */
export const REMINDER_HOUR = 19;
/** Shortest streak worth a reminder. */
export const REMINDER_MIN_STREAK = 3;
const HOUR = 3_600_000;

/**
 * The daily check-in streak: one more for every day in a row a Manager opens
 * the app (domain/visit-streak.ts), a notification at the milestones, and an
 * evening reminder when a streak of a few days is about to end.
 */
@Injectable()
export class StreakService implements OnModuleInit {
  private readonly logger = new Logger(StreakService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly sessions: SessionService,
    private readonly notifications: NotificationsService,
    private readonly scheduler: SchedulerRegistry,
  ) {}

  onModuleInit() {
    this.sessions.onVisit(async (userId, day) => {
      await this.recordVisit(userId, day);
    });
    const interval = setInterval(() => {
      this.remindAtRisk().catch((e) => this.logger.error(`Streak reminders failed: ${String(e)}`));
    }, HOUR);
    this.scheduler.addInterval('streak-reminders', interval);
  }

  /**
   * Counts a visit on [day]. Guarded in SQL, so two requests (or two servers)
   * can't count the same day twice. Returns the streak, or null when the day
   * was already counted.
   */
  async recordVisit(userId: string, day: string): Promise<number | null> {
    const yesterday = dayBefore(day);
    const row = await this.db
      .updateTable('users')
      .set({
        visit_streak: sql<number>`case when last_visit_day = ${yesterday}::date then visit_streak + 1 else 1 end`,
        best_visit_streak: sql<number>`greatest(best_visit_streak,
          case when last_visit_day = ${yesterday}::date then visit_streak + 1 else 1 end)`,
        last_visit_day: sql<string>`${day}::date`,
      })
      .where('id', '=', userId)
      .where('is_seed', '=', false)
      .where((eb) => eb.or([eb('last_visit_day', 'is', null), eb('last_visit_day', '<', sql<string>`${day}::date`)]))
      .returning('visit_streak')
      .executeTakeFirst();
    if (!row) return null;

    if (isMilestone(row.visit_streak)) {
      await this.notifications.push({
        userId,
        kind: 'streak',
        title: `${row.visit_streak}-day streak`,
        body: `You've checked your team ${row.visit_streak} days running. Come back tomorrow to keep it going.`,
        data: { streak: row.visit_streak, type: 'milestone' },
      });
    }
    return row.visit_streak;
  }

  /**
   * In the evening, in each Manager's own time zone: a streak of a few days
   * that hasn't been kept today ends at midnight, so say so, once.
   */
  async remindAtRisk(): Promise<number> {
    const now = this.clock.now();
    const candidates = await this.db
      .selectFrom('users')
      .leftJoin('push_preferences', 'push_preferences.user_id', 'users.id')
      .select([
        'users.id as id',
        'users.visit_streak as streak',
        'push_preferences.time_zone as zone',
        sql<string>`to_char(users.last_visit_day, 'YYYY-MM-DD')`.as('last_day'),
      ])
      .where('users.visit_streak', '>=', REMINDER_MIN_STREAK)
      .where('users.is_seed', '=', false)
      .where('users.suspended_at', 'is', null)
      .where('users.deleted_at', 'is', null)
      // Cheap first cut; the exact check is per time zone below.
      .where('users.last_visit_day', '>=', sql<string>`${new Date(now - 3 * 24 * HOUR).toISOString().slice(0, 10)}::date`)
      .execute();

    const due = candidates.filter((c) => {
      const zone = c.zone ?? 'UTC';
      const today = localDay(now, zone);
      return c.last_day === dayBefore(today) && localHour(now, zone) >= REMINDER_HOUR;
    });
    if (due.length === 0) return 0;

    // Once per evening: skip anyone already reminded in the last 20 hours.
    const reminded = await this.db
      .selectFrom('notifications')
      .select('user_id')
      .where('kind', '=', 'streak')
      .where('created_at', '>', new Date(now - 20 * HOUR))
      .where(sql<boolean>`data->>'type' = 'at_risk'`)
      .where(
        'user_id',
        'in',
        due.map((d) => d.id),
      )
      .execute();
    const skip = new Set(reminded.map((r) => r.user_id));
    const send = due.filter((d) => !skip.has(d.id));

    await this.notifications.pushMany(
      send.map((d) => ({
        userId: d.id,
        kind: 'streak' as const,
        title: `Your ${d.streak}-day streak ends at midnight`,
        body: 'Open Formation and check your team to keep it going.',
        data: { streak: d.streak, type: 'at_risk' },
      })),
    );
    return send.length;
  }
}

const hourFormats = new Map<string, Intl.DateTimeFormat>();

/** The hour (0-23) it is at [at] in [zone]. */
function localHour(at: number, zone: string): number {
  let format = hourFormats.get(zone);
  if (!format) {
    try {
      format = new Intl.DateTimeFormat('en-GB', { timeZone: zone, hour: '2-digit', hourCycle: 'h23' });
    } catch {
      format = new Intl.DateTimeFormat('en-GB', { timeZone: 'UTC', hour: '2-digit', hourCycle: 'h23' });
    }
    hourFormats.set(zone, format);
  }
  return Number(format.format(new Date(at)));
}

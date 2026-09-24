import { Inject, Injectable } from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { NotificationKind } from '../core/db-types.js';
import type { NotificationDto } from '../domain/dto.js';

const INBOX_SIZE = 50;

export interface NewNotification {
  userId: string;
  kind: NotificationKind;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

/**
 * In-app notifications.
 *
 * Only events worth interrupting someone for are written: the daily points
 * rollup, and leagues starting, settling or gaining a member. Per-tick alpha
 * is deliberately excluded — it fires constantly and would train players to
 * ignore the bell.
 */
@Injectable()
export class NotificationsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async list(userId: string): Promise<NotificationDto[]> {
    const rows = await this.db
      .selectFrom('notifications')
      .selectAll()
      .where('user_id', '=', userId)
      .orderBy('created_at', 'desc')
      .limit(INBOX_SIZE)
      .execute();

    return rows.map((row) => ({
      id: row.id,
      kind: row.kind,
      title: row.title,
      body: row.body,
      data: (row.data ?? null) as Record<string, unknown> | null,
      read: row.read_at !== null,
      createdAt: new Date(row.created_at).toISOString(),
    }));
  }

  async unreadCount(userId: string): Promise<number> {
    const row = await this.db
      .selectFrom('notifications')
      .select((eb) => eb.fn.countAll<string>().as('count'))
      .where('user_id', '=', userId)
      .where('read_at', 'is', null)
      .executeTakeFirst();
    return Number(row?.count ?? 0);
  }

  async markRead(userId: string, id: string): Promise<void> {
    await this.db
      .updateTable('notifications')
      .set({ read_at: this.clock.date() })
      .where('id', '=', id)
      .where('user_id', '=', userId)
      .where('read_at', 'is', null)
      .execute();
  }

  async markAllRead(userId: string): Promise<void> {
    await this.db
      .updateTable('notifications')
      .set({ read_at: this.clock.date() })
      .where('user_id', '=', userId)
      .where('read_at', 'is', null)
      .execute();
  }

  /** Writes one notification. Never throws into the caller's flow. */
  async push(notification: NewNotification): Promise<void> {
    await this.pushMany([notification]);
  }

  /** Writes a batch, e.g. one per member when a league settles. */
  async pushMany(notifications: NewNotification[]): Promise<void> {
    if (notifications.length === 0) return;
    await this.db
      .insertInto('notifications')
      .values(
        notifications.map((n) => ({
          user_id: n.userId,
          kind: n.kind,
          title: n.title,
          body: n.body,
          data: n.data === undefined ? null : JSON.stringify(n.data),
          created_at: this.clock.date(),
        })),
      )
      .execute();
  }
}

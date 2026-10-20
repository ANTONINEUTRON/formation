import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';

/** Shortest reason an admin write accepts; the migration enforces it too. */
export const MIN_REASON = 5;

export interface AdminActionInput {
  /** Wallet address of the admin, or 'key'. */
  admin: string;
  /** e.g. score.correct, user.suspend, credits.grant */
  action: string;
  targetUserId?: string | null;
  reason: string;
  /** Before and after values, amounts. Never personal detail. */
  detail?: unknown;
}

export interface AdminActionDto {
  id: string;
  admin: string;
  action: string;
  targetUserId: string | null;
  targetUsername: string | null;
  reason: string;
  detail: unknown;
  createdAt: string;
}

/** A reason from a request body, trimmed, or a 400 explaining what's needed. */
export function requireReason(value: unknown): string {
  const reason = typeof value === 'string' ? value.trim() : '';
  if (reason.length < MIN_REASON) {
    throw new BadRequestException(`Give a reason of at least ${MIN_REASON} characters`);
  }
  return reason.slice(0, 500);
}

/**
 * The admin audit log. Every admin write records itself here through
 * [record], inside the transaction that makes the change, so there is never a
 * change without a record or a record without its change.
 */
@Injectable()
export class AdminAuditService {
  constructor(@Inject(DB) private readonly db: Db) {}

  async record(trx: Db, input: AdminActionInput): Promise<AdminActionDto> {
    const row = await trx
      .insertInto('admin_actions')
      .values({
        admin: input.admin,
        action: input.action,
        target_user_id: input.targetUserId ?? null,
        reason: requireReason(input.reason),
        detail: input.detail === undefined ? null : JSON.stringify(input.detail),
      })
      .returningAll()
      .executeTakeFirstOrThrow();
    return {
      id: row.id,
      admin: row.admin,
      action: row.action,
      targetUserId: row.target_user_id,
      targetUsername: null,
      reason: row.reason,
      detail: row.detail,
      createdAt: new Date(row.created_at).toISOString(),
    };
  }

  /** Runs [change] and records it, together or not at all. */
  async run<T>(
    input: AdminActionInput,
    change: (trx: Db) => Promise<{ result: T; detail?: unknown }>,
  ): Promise<{ result: T; action: AdminActionDto }> {
    // Fail on a bad reason before touching anything.
    requireReason(input.reason);
    return this.db.transaction().execute(async (trx) => {
      const { result, detail } = await change(trx);
      const action = await this.record(trx, { ...input, detail: detail ?? input.detail });
      return { result, action };
    });
  }

  /** Newest first, filtered by admin, action prefix or Manager. Pages by `before`. */
  async list(query: {
    admin?: string;
    action?: string;
    userId?: string;
    before?: string;
    limit?: string;
  }): Promise<AdminActionDto[]> {
    const limit = Math.min(200, Math.max(1, Number(query.limit) || 50));
    let q = this.db
      .selectFrom('admin_actions')
      .leftJoin('users', 'users.id', 'admin_actions.target_user_id')
      .selectAll('admin_actions')
      .select('users.username as target_username')
      .orderBy('admin_actions.created_at', 'desc')
      .limit(limit);
    if (query.admin) q = q.where('admin_actions.admin', '=', query.admin);
    if (query.action) q = q.where('admin_actions.action', 'like', `${query.action.replace(/[%_]/g, '')}%`);
    if (query.userId && UUID.test(query.userId)) q = q.where('admin_actions.target_user_id', '=', query.userId);
    if (query.before && !Number.isNaN(Date.parse(query.before))) {
      q = q.where('admin_actions.created_at', '<', new Date(query.before));
    }
    const rows = await q.execute();
    return rows.map((r) => ({
      id: r.id,
      admin: r.admin,
      action: r.action,
      targetUserId: r.target_user_id,
      targetUsername: r.target_username,
      reason: r.reason,
      detail: r.detail,
      createdAt: new Date(r.created_at).toISOString(),
    }));
  }
}

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

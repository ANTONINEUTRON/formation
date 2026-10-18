import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { CreditReason } from '../core/db-types.js';

/**
 * Assistant credits: the one balance every paid Assistant Manager action
 * spends (replies, squad drafts, avatars), held on the server per account.
 *
 * An account is its wallet, so reconnecting or reinstalling finds the same
 * balance, and the welcome grant is given once per account, ever.
 *
 * The balance only moves through single guarded statements, so two requests
 * racing each other can never spend the same credit, and every move is
 * written to `credit_ledger` in the same transaction.
 */
@Injectable()
export class CreditsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  /** The balance, granting the welcome credits the first time an account is seen. */
  async balance(userId: string): Promise<number> {
    await this.welcome(userId);
    const row = await this.db
      .selectFrom('assistant_credits')
      .select('balance')
      .where('user_id', '=', userId)
      .executeTakeFirstOrThrow();
    return row.balance;
  }

  /** Takes [cost] credits. Returns the new balance, or null if there weren't enough. */
  async charge(userId: string, cost: number, reason: CreditReason): Promise<number | null> {
    await this.welcome(userId);
    return this.db.transaction().execute(async (trx) => {
      const row = await trx
        .updateTable('assistant_credits')
        .set({ balance: sql<number>`balance - ${cost}`, updated_at: this.clock.date() })
        .where('user_id', '=', userId)
        .where('balance', '>=', cost)
        .returning('balance')
        .executeTakeFirst();
      if (!row) return null;
      await this.record(trx, userId, -cost, row.balance, reason, null);
      return row.balance;
    });
  }

  /** Returns credits taken by a charge for [reason] that then failed. */
  async refund(userId: string, cost: number, reason: CreditReason): Promise<number> {
    return this.db.transaction().execute(async (trx) => {
      const row = await trx
        .updateTable('assistant_credits')
        .set({ balance: sql<number>`balance + ${cost}`, updated_at: this.clock.date() })
        .where('user_id', '=', userId)
        .returning('balance')
        .executeTakeFirstOrThrow();
      await this.record(trx, userId, cost, row.balance, 'refund', reason);
      return row.balance;
    });
  }

  /**
   * Adds bought credits inside the caller's transaction, so the purchase and
   * the credits land together or not at all.
   */
  async addPurchased(trx: Db, userId: string, credits: number, signature: string): Promise<number> {
    await this.welcome(userId, trx);
    const row = await trx
      .updateTable('assistant_credits')
      .set({ balance: sql<number>`balance + ${credits}`, updated_at: this.clock.date() })
      .where('user_id', '=', userId)
      .returning('balance')
      .executeTakeFirstOrThrow();
    await this.record(trx, userId, credits, row.balance, 'purchase', signature);
    return row.balance;
  }

  /** The welcome grant: only the insert that creates the account's row gives it. */
  private async welcome(userId: string, db: Db = this.db): Promise<void> {
    const grant = Math.max(0, this.config.assistantTrialCredits);
    const created = await db
      .insertInto('assistant_credits')
      .values({ user_id: userId, balance: grant, trial_granted: true })
      .onConflict((oc) => oc.column('user_id').doNothing())
      .returning('balance')
      .executeTakeFirst();
    if (created) await this.record(db, userId, grant, created.balance, 'welcome', null);
  }

  private async record(
    db: Db,
    userId: string,
    delta: number,
    balanceAfter: number,
    reason: CreditReason,
    ref: string | null,
  ): Promise<void> {
    await db
      .insertInto('credit_ledger')
      .values({ user_id: userId, delta, balance_after: balanceAfter, reason, ref })
      .execute();
  }
}

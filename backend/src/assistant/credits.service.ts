import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';

/**
 * Assistant credits. One credit pays for one reply.
 *
 * The balance only moves through single guarded statements, so two replies
 * racing each other can never spend the same credit, and a refund can only
 * return what a charge took.
 */
@Injectable()
export class CreditsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  /** The balance, granting the trial allowance the first time a Manager is seen. */
  async balance(userId: string): Promise<number> {
    await this.db
      .insertInto('assistant_credits')
      .values({
        user_id: userId,
        balance: Math.max(0, this.config.assistantTrialCredits),
        trial_granted: true,
      })
      .onConflict((oc) => oc.column('user_id').doNothing())
      .execute();
    const row = await this.db
      .selectFrom('assistant_credits')
      .select('balance')
      .where('user_id', '=', userId)
      .executeTakeFirstOrThrow();
    return row.balance;
  }

  /** Takes [cost] credits. Returns the new balance, or null if there weren't enough. */
  async charge(userId: string, cost: number): Promise<number | null> {
    await this.balance(userId);
    const row = await this.db
      .updateTable('assistant_credits')
      .set({ balance: sql<number>`balance - ${cost}`, updated_at: this.clock.date() })
      .where('user_id', '=', userId)
      .where('balance', '>=', cost)
      .returning('balance')
      .executeTakeFirst();
    return row?.balance ?? null;
  }

  /** Returns credits taken by a charge whose reply failed. */
  async refund(userId: string, cost: number): Promise<number> {
    const row = await this.db
      .updateTable('assistant_credits')
      .set({ balance: sql<number>`balance + ${cost}`, updated_at: this.clock.date() })
      .where('user_id', '=', userId)
      .returning('balance')
      .executeTakeFirstOrThrow();
    return row.balance;
  }
}

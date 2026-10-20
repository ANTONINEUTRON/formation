import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';

const DAY = 24 * 3_600_000;

export interface AssistantDayDto {
  day: string;
  purchases: number;
  creditsSold: number;
  usd: number;
  skr: number;
  creditsUsed: number;
  requests: number;
  failed: number;
  tokensIn: number;
  tokensOut: number;
  estimatedCostUsd: number;
}

/**
 * What the Assistant Manager costs and earns (ADMIN_PLAN.md Phase 3): credits
 * sold against credits used and the Gemini tokens behind them, the heaviest
 * users this week, and a purchase lookup for "I paid but got no credits".
 */
@Injectable()
export class AdminAssistantService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async overview() {
    const now = this.clock.now();
    const from = new Date(now - 29 * DAY);
    from.setUTCHours(0, 0, 0, 0);
    const weekStart = new Date(now - 7 * DAY);

    const [sold, used, top] = await Promise.all([
      sql<{ day: string; purchases: string; credits: string; usd: string; skr_raw: string }>`
        select to_char(date_trunc('day', created_at at time zone 'UTC'), 'YYYY-MM-DD') as day,
               count(*) as purchases, sum(credits) as credits, sum(usd) as usd, sum(skr_raw) as skr_raw
        from credit_purchases
        where created_at >= ${from}
        group by 1
      `.execute(this.db),
      sql<{ day: string; credits: string; requests: string; failed: string; tokens_in: string; tokens_out: string }>`
        select to_char(date_trunc('day', created_at at time zone 'UTC'), 'YYYY-MM-DD') as day,
               sum(credits) as credits, count(*) as requests,
               count(*) filter (where not succeeded) as failed,
               sum(tokens_in) as tokens_in, sum(tokens_out) as tokens_out
        from assistant_usage
        where created_at >= ${from}
        group by 1
      `.execute(this.db),
      this.db
        .selectFrom('assistant_usage')
        .innerJoin('users', 'users.id', 'assistant_usage.user_id')
        .leftJoin('assistant_credits', 'assistant_credits.user_id', 'assistant_usage.user_id')
        .select((eb) => [
          'users.id as id',
          'users.username as username',
          eb.fn.sum<string>('assistant_usage.credits').as('credits'),
          eb.fn.countAll<string>().as('requests'),
          eb.fn.sum<string>('assistant_usage.tokens_in').as('tokens_in'),
          eb.fn.sum<string>('assistant_usage.tokens_out').as('tokens_out'),
          eb.fn.max('assistant_credits.balance').as('balance'),
        ])
        .where('assistant_usage.created_at', '>=', weekStart)
        .groupBy(['users.id', 'users.username'])
        .orderBy(sql`sum(assistant_usage.credits)`, 'desc')
        .limit(20)
        .execute(),
    ]);

    // SKR's decimals, for showing raw amounts.
    const skrDecimals = this.config.payTokens.find((t) => t.symbol === 'SKR')?.decimals ?? 6;
    const days: AssistantDayDto[] = [];
    for (let i = 0; i < 30; i++) {
      const day = new Date(from.getTime() + i * DAY).toISOString().slice(0, 10);
      const s = sold.rows.find((r) => r.day === day);
      const u = used.rows.find((r) => r.day === day);
      const tokensIn = Number(u?.tokens_in ?? 0);
      const tokensOut = Number(u?.tokens_out ?? 0);
      days.push({
        day,
        purchases: Number(s?.purchases ?? 0),
        creditsSold: Number(s?.credits ?? 0),
        usd: Math.round(Number(s?.usd ?? 0) * 100) / 100,
        skr: Number(s?.skr_raw ?? 0) / 10 ** skrDecimals,
        creditsUsed: Number(u?.credits ?? 0),
        requests: Number(u?.requests ?? 0),
        failed: Number(u?.failed ?? 0),
        tokensIn,
        tokensOut,
        estimatedCostUsd: this.cost(tokensIn, tokensOut),
      });
    }
    days.reverse();

    const totals = days.reduce(
      (t, d) => ({
        usd: t.usd + d.usd,
        cost: t.cost + d.estimatedCostUsd,
        creditsSold: t.creditsSold + d.creditsSold,
        creditsUsed: t.creditsUsed + d.creditsUsed,
      }),
      { usd: 0, cost: 0, creditsSold: 0, creditsUsed: 0 },
    );

    return {
      days,
      totals: {
        usd: Math.round(totals.usd * 100) / 100,
        estimatedCostUsd: Math.round(totals.cost * 100) / 100,
        creditsSold: totals.creditsSold,
        creditsUsed: totals.creditsUsed,
      },
      pricing: {
        perMtokIn: this.config.assistantCostPerMtokIn,
        perMtokOut: this.config.assistantCostPerMtokOut,
      },
      topUsers: top.map((t) => ({
        id: t.id,
        username: t.username,
        credits: Number(t.credits ?? 0),
        requests: Number(t.requests),
        estimatedCostUsd: this.cost(Number(t.tokens_in ?? 0), Number(t.tokens_out ?? 0)),
        balance: t.balance === null ? null : Number(t.balance),
      })),
    };
  }

  private cost(tokensIn: number, tokensOut: number): number {
    const usd =
      (tokensIn / 1e6) * this.config.assistantCostPerMtokIn + (tokensOut / 1e6) * this.config.assistantCostPerMtokOut;
    return Math.round(usd * 10_000) / 10_000;
  }

  /**
   * Everything known about a payment, by transaction signature: the purchase
   * if it was credited, and the quote it paid. A signature with no purchase
   * means the server never credited it; the explorer link shows whether it
   * landed on chain.
   */
  async purchase(signature: string) {
    const sig = signature.trim();
    const purchase = await this.db
      .selectFrom('credit_purchases')
      .innerJoin('users', 'users.id', 'credit_purchases.user_id')
      .leftJoin('credit_quotes', 'credit_quotes.id', 'credit_purchases.quote_id')
      .select([
        'credit_purchases.signature as signature',
        'credit_purchases.credits as credits',
        'credit_purchases.usd as usd',
        'credit_purchases.skr_raw as skr_raw',
        'credit_purchases.created_at as created_at',
        'users.id as user_id',
        'users.username as username',
        'credit_quotes.pack_id as pack_id',
        'credit_quotes.created_at as quoted_at',
        'credit_quotes.expires_at as expires_at',
      ])
      .where('credit_purchases.signature', '=', sig)
      .executeTakeFirst();
    return {
      signature: sig,
      explorerUrl: `https://solscan.io/tx/${encodeURIComponent(sig)}`,
      found: purchase !== undefined,
      purchase: purchase
        ? {
            credits: purchase.credits,
            usd: Number(purchase.usd),
            skrRaw: Number(purchase.skr_raw),
            creditedAt: new Date(purchase.created_at).toISOString(),
            userId: purchase.user_id,
            username: purchase.username,
            packId: purchase.pack_id,
            quotedAt: purchase.quoted_at ? new Date(purchase.quoted_at).toISOString() : null,
            quoteExpiresAt: purchase.expires_at ? new Date(purchase.expires_at).toISOString() : null,
          }
        : null,
    };
  }

  /** A Manager's recent quotes, for the case where they paid but no purchase exists. */
  async quotesFor(userId: string) {
    const rows = await this.db
      .selectFrom('credit_quotes')
      .select(['id', 'pack_id', 'credits', 'usd', 'skr_raw', 'created_at', 'expires_at', 'used_at'])
      .where('user_id', '=', userId)
      .orderBy('created_at', 'desc')
      .limit(20)
      .execute();
    return rows.map((q) => ({
      id: q.id,
      packId: q.pack_id,
      credits: q.credits,
      usd: Number(q.usd),
      skrRaw: Number(q.skr_raw),
      createdAt: new Date(q.created_at).toISOString(),
      expiresAt: new Date(q.expires_at).toISOString(),
      usedAt: q.used_at ? new Date(q.used_at).toISOString() : null,
    }));
  }
}

import { Inject, Injectable, Logger } from '@nestjs/common';
import { sql } from 'kysely';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { FORMATIONS, formationName, rosterShape, RISK_TIERS, SPORT_MODES } from '../domain/sport.js';
import type { RiskTier, SportMode } from '../domain/sport.js';
import { planTiers, TIER_WINDOW_DAYS } from '../domain/tiers.js';
import type { DailyClose, TierDecision } from '../domain/tiers.js';
import { XStocksService } from './xstocks.service.js';

/** A sport whose biggest lineup needs more stocks of a tier than are listed. */
export interface TierShortage {
  mode: SportMode;
  tier: RiskTier;
  needed: number;
  listed: number;
}

export interface TierPlan {
  decisions: TierDecision[];
  shortages: TierShortage[];
}

/**
 * Runs the tier formula (`domain/tiers.ts`) against stored prices: once each
 * season from SeasonService, or by hand with `npm run tiers`.
 */
@Injectable()
export class TiersService {
  private readonly logger = new Logger(TiersService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    private readonly xstocks: XStocksService,
  ) {}

  async plan(now: number): Promise<TierPlan> {
    const rows = await this.db
      .selectFrom('xstocks')
      .select(['mint', 'symbol', 'company_name', 'tier', 'tier_source'])
      .execute();
    const closes = await this.dailyCloses(now);
    const benchmark = closes.get(this.config.benchmarkMint) ?? [];

    const decisions = planTiers(
      rows.map((r) => ({
        mint: r.mint,
        symbol: r.symbol,
        companyName: r.company_name,
        tier: r.tier,
        source: r.tier_source,
        closes: closes.get(r.mint) ?? [],
      })),
      benchmark,
    );
    return { decisions, shortages: this.shortages(decisions) };
  }

  /** Saves the plan's tiers. Manual tiers are never touched. Returns how many changed. */
  async apply(now: number): Promise<TierPlan & { changed: number }> {
    const plan = await this.plan(now);
    const changes = plan.decisions.filter((d) => d.reason !== 'manual' && d.next !== d.current);
    for (const d of changes) {
      await this.db
        .updateTable('xstocks')
        .set({ tier: d.next })
        .where('mint', '=', d.mint)
        .where('tier_source', '=', 'formula')
        .execute();
    }
    if (changes.length > 0) this.xstocks.invalidate();
    this.logger.log(
      `Tiers applied: ${changes.length} changed` +
        (changes.length ? ` (${changes.map((d) => `${d.symbol} ${d.current}→${d.next}`).join(', ')})` : ''),
    );
    for (const s of plan.shortages) {
      this.logger.warn(`Only ${s.listed} ${s.tier} stocks for ${s.mode}, which can need ${s.needed}`);
    }
    return { ...plan, changed: changes.length };
  }

  /** The last price of each weekday over the window, per mint. */
  private async dailyCloses(now: number): Promise<Map<string, DailyClose[]>> {
    const since = new Date(now - TIER_WINDOW_DAYS * 86_400_000);
    // Days as epoch milliseconds of UTC midnight, so no driver time zone applies.
    const result = await sql<{ mint: string; day_ms: string; price: number }>`
      select distinct on (mint, day_ms) mint, day_ms, price_usd as price
      from (
        select mint, price_usd, captured_at,
          (extract(epoch from date_trunc('day', captured_at at time zone 'UTC')) * 1000)::bigint as day_ms
        from price_ticks
        where captured_at >= ${since}
      ) ticks
      order by mint, day_ms, captured_at desc
    `.execute(this.db);

    const out = new Map<string, DailyClose[]>();
    for (const row of result.rows) {
      const list = out.get(row.mint) ?? [];
      list.push({ day: Number(row.day_ms), price: Number(row.price) });
      out.set(row.mint, list);
    }
    return out;
  }

  /** Where a sport's largest lineup would need more stocks of a tier than are listed. */
  private shortages(decisions: TierDecision[]): TierShortage[] {
    const count = new Map<RiskTier, number>();
    for (const d of decisions) count.set(d.next, (count.get(d.next) ?? 0) + 1);

    const out: TierShortage[] = [];
    for (const mode of SPORT_MODES) {
      for (const tier of RISK_TIERS) {
        const needed = mostSlots(mode, tier);
        const have = count.get(tier) ?? 0;
        if (have < needed) out.push({ mode, tier, needed, listed: have });
      }
    }
    return out;
  }
}

/** The most slots of [tier] any lineup in [mode] has. Football's depends on the formation. */
function mostSlots(mode: SportMode, tier: RiskTier): number {
  const shapes = mode === 'football' ? FORMATIONS.map(formationName) : [undefined];
  return Math.max(...shapes.map((f) => rosterShape(mode, f).filter((p) => p.tier === tier).length));
}

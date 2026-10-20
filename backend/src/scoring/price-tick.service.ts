import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { PRICE_SOURCE } from '../core/sources.js';
import type { PriceSource } from '../core/sources.js';
import { LeaguesService } from '../leagues/leagues.service.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { GeneralScoringService } from './general-scoring.service.js';
import { MatchWeekService } from './match-week.service.js';
import { SeasonService } from './season.service.js';

/**
 * Records a price for every xStock on an interval, then banks the general
 * league. The interval comes from config (short in the demo profile), so it's
 * registered at runtime rather than with a @Cron decorator.
 */
@Injectable()
export class PriceTickService implements OnModuleInit {
  private readonly logger = new Logger(PriceTickService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
    private readonly xstocks: XStocksService,
    private readonly general: GeneralScoringService,
    private readonly seasons: SeasonService,
    private readonly matchWeeks: MatchWeekService,
    private readonly leagues: LeaguesService,
    private readonly scheduler: SchedulerRegistry,
  ) {}

  onModuleInit() {
    const every = Math.max(1, this.config.priceTickMinutes) * 60_000;
    const interval = setInterval(() => {
      this.tick().catch((e) => this.logger.error(`Price tick failed: ${String(e)}`));
    }, every);
    this.scheduler.addInterval('price-tick', interval);
  }

  /** One price snapshot plus gameweek processing. */
  async tick(): Promise<{ mints: number; capturedAt: Date }> {
    const rows = await this.xstocks.rows();
    const mints = rows.map((r) => r.mint);
    const prices = await this.prices.getPrices(mints, { fresh: true });
    const capturedAt = this.clock.date();

    const values = mints
      .filter((mint) => (prices.get(mint)?.usdPrice ?? 0) > 0)
      .map((mint) => ({
        mint,
        price_usd: prices.get(mint)!.usdPrice,
        captured_at: capturedAt,
      }));
    if (values.length > 0) {
      await this.db
        .insertInto('price_ticks')
        .values(values)
        .onConflict((oc) => oc.columns(['mint', 'captured_at']).doNothing())
        .execute();
    }

    // A season that ended closes before this tick banks into the next one.
    try {
      await this.seasons.rollover(capturedAt.getTime());
    } catch (e) {
      this.logger.error(`Season rollover failed: ${String(e)}`);
    }

    // Points bank here, on every tick — nothing waits for a window to close.
    await this.general.process(capturedAt.getTime());

    // Leagues have their own timer; this catches any it missed (a restart).
    try {
      await this.leagues.processDue();
    } catch (e) {
      this.logger.error(`League processing failed: ${String(e)}`);
    }

    // Kick-off, half-time and full time ride on the tick that crosses them.
    try {
      await this.matchWeeks.process(capturedAt.getTime());
    } catch (e) {
      this.logger.error(`Match week processing failed: ${String(e)}`);
    }
    return { mints: values.length, capturedAt };
  }
}

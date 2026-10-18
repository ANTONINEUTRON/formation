import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { DEPTH_SOURCE } from '../core/sources.js';
import type { DepthSource } from '../core/sources.js';
import { XStocksService } from '../xstocks/xstocks.service.js';

/** A stock's latest depth reading. Null loss means no route at all. */
export interface DepthReading {
  lossPct: number | null;
  checkedAt: number;
}

/**
 * Measures how deep each stock's market is, on its own timer, one stock at a
 * time so Jupiter's rate limit is respected. AssetScoringService reads the
 * results: a stock only scores while its round trip is cheap, because a pool
 * that's cheap to trade through is one a player can push around for points.
 */
@Injectable()
export class MarketDepthService implements OnModuleInit {
  private readonly logger = new Logger(MarketDepthService.name);
  private running = false;

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(DEPTH_SOURCE) private readonly source: DepthSource,
    private readonly xstocks: XStocksService,
    private readonly scheduler: SchedulerRegistry,
  ) {}

  onModuleInit() {
    const minutes = this.config.depthCheckMinutes;
    if (minutes <= 0) {
      this.logger.log('Market depth checks disabled (DEPTH_CHECK_MINUTES=0)');
      return;
    }
    const run = () => {
      this.checkAll().catch((e) => this.logger.error(`Depth check failed: ${String(e)}`));
    };
    this.scheduler.addInterval('market-depth', setInterval(run, minutes * 60_000));
    // A first reading soon after boot, without holding the boot up.
    this.scheduler.addTimeout('market-depth-boot', setTimeout(run, 30_000));
  }

  /** Measures every listed stock once. Overlapping runs are skipped. */
  async checkAll(): Promise<{ checked: number; failed: number }> {
    if (this.running) return { checked: 0, failed: 0 };
    this.running = true;
    let checked = 0;
    let failed = 0;
    try {
      for (const row of await this.xstocks.rows()) {
        try {
          const lossPct = await this.source.roundTripLossPct(row.mint, this.config.depthProbeUsd);
          await this.save(row.mint, lossPct);
          checked++;
        } catch (e) {
          // Unreachable, not thin: keep the last reading rather than guess.
          failed++;
          this.logger.warn(`Depth check for ${row.symbol} failed: ${String(e)}`);
        }
        await new Promise((r) => setTimeout(r, this.config.quoteSpacingMs));
      }
    } finally {
      this.running = false;
    }
    this.logger.log(`Market depth checked: ${checked} stocks${failed ? `, ${failed} unreachable` : ''}`);
    return { checked, failed };
  }

  async save(mint: string, lossPct: number | null, at = Date.now()): Promise<void> {
    await this.db
      .insertInto('market_depth')
      .values({
        mint,
        round_trip_loss_pct: lossPct,
        probe_usd: this.config.depthProbeUsd,
        checked_at: new Date(at),
      })
      .onConflict((oc) =>
        oc.column('mint').doUpdateSet((eb) => ({
          round_trip_loss_pct: eb.ref('excluded.round_trip_loss_pct'),
          probe_usd: eb.ref('excluded.probe_usd'),
          checked_at: eb.ref('excluded.checked_at'),
        })),
      )
      .execute();
  }

  /** Every stock's latest reading. A stock never measured is absent. */
  async latest(): Promise<Map<string, DepthReading>> {
    const rows = await this.db.selectFrom('market_depth').selectAll().execute();
    return new Map(
      rows.map((r) => [
        r.mint,
        { lossPct: r.round_trip_loss_pct, checkedAt: new Date(r.checked_at).getTime() },
      ]),
    );
  }
}

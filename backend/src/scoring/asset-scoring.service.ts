import { Inject, Injectable, Logger } from '@nestjs/common';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { benchmarkMintFor } from '../domain/assets.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import {
  assessAsset,
  ELIGIBILITY_WINDOW_MS,
  nextStatus,
  NOT_SCORING_LABELS,
} from './engine/eligibility.js';
import type { NotScoringReason, ScoringStatus } from './engine/eligibility.js';
import type { PriceTick } from './engine/types.js';

/**
 * Decides, on every price tick, which assets score (SCORING_PLAN.md §1.2).
 *
 * The rules are the same for every asset and are measured from its own price
 * data over the trailing day, so nothing is hand-picked: an asset whose pool
 * stops trading stops scoring, and starts again a day after it recovers.
 */
@Injectable()
export class AssetScoringService {
  private readonly logger = new Logger(AssetScoringService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    private readonly xstocks: XStocksService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Re-assesses every listed asset as of [now]. */
  async refresh(now: number): Promise<{ notScoring: number }> {
    const rows = await this.xstocks.rows();
    if (rows.length === 0) return { notScoring: 0 };

    const ticks = await this.db
      .selectFrom('price_ticks')
      .select(['mint', 'price_usd', 'captured_at'])
      .where('captured_at', '>', new Date(now - ELIGIBILITY_WINDOW_MS))
      .where('captured_at', '<=', new Date(now))
      .orderBy('captured_at')
      .execute();
    const book = new Map<string, PriceTick[]>();
    for (const t of ticks) {
      const series = book.get(t.mint) ?? [];
      series.push({ at: new Date(t.captured_at).getTime(), price: t.price_usd });
      book.set(t.mint, series);
    }

    const previous = new Map(
      (await this.db.selectFrom('asset_scoring_status').selectAll().execute()).map((r) => [
        r.mint,
        {
          eligible: r.eligible,
          reason: r.reason as NotScoringReason | null,
          since: new Date(r.since).getTime(),
          passingSince: r.passing_since ? new Date(r.passing_since).getTime() : null,
        } satisfies ScoringStatus,
      ]),
    );
    const mintBySymbol = new Map(rows.map((r) => [r.symbol, r.mint]));

    const statuses: {
      mint: string;
      eligible: boolean;
      reason: NotScoringReason | null;
      since: Date;
      passing_since: Date | null;
      checked_at: Date;
      metrics: string;
    }[] = [];
    const anomalies: { mint: string; at: Date; kind: 'jump' | 'status'; detail: string | null }[] = [];
    for (const row of rows) {
      const benchmark = benchmarkMintFor(row.asset_class, mintBySymbol, this.config.benchmarkMint);
      // A benchmark is the yardstick, not a pick being judged against it.
      const assessment =
        row.mint === benchmark
          ? { failure: null, metrics: {}, jumpTimes: [] }
          : assessAsset({
              ticks: book.get(row.mint) ?? [],
              benchmark: book.get(benchmark) ?? [],
              now,
              tickMinutes: this.config.priceTickMinutes,
              liquidityUsd: row.liquidity_usd,
              minLiquidityUsd: this.config.scoringMinLiquidityUsd,
              maxMove: this.config.maxTickMove,
            });
      const before = previous.get(row.mint);
      const status = nextStatus(before, assessment.failure, now);

      statuses.push({
        mint: row.mint,
        eligible: status.eligible,
        reason: status.reason,
        since: new Date(status.since),
        passing_since: status.passingSince === null ? null : new Date(status.passingSince),
        checked_at: new Date(now),
        metrics: JSON.stringify(assessment.metrics),
      });
      if (before && before.eligible !== status.eligible) {
        anomalies.push({
          mint: row.mint,
          at: new Date(now),
          kind: 'status' as const,
          detail: JSON.stringify({ eligible: status.eligible, reason: status.reason }),
        });
        this.logger.log(
          `${row.symbol} ${status.eligible ? 'is scoring again' : `stopped scoring: ${status.reason}`}`,
        );
      }
      for (const at of assessment.jumpTimes) {
        anomalies.push({ mint: row.mint, at: new Date(at), kind: 'jump' as const, detail: null });
      }
    }

    await this.db
      .insertInto('asset_scoring_status')
      .values(statuses)
      .onConflict((oc) =>
        oc.column('mint').doUpdateSet((eb) => ({
          eligible: eb.ref('excluded.eligible'),
          reason: eb.ref('excluded.reason'),
          since: eb.ref('excluded.since'),
          passing_since: eb.ref('excluded.passing_since'),
          checked_at: eb.ref('excluded.checked_at'),
          metrics: eb.ref('excluded.metrics'),
        })),
      )
      .execute();
    if (anomalies.length > 0) {
      await this.db
        .insertInto('scoring_anomalies')
        .values(anomalies)
        .onConflict((oc) => oc.columns(['mint', 'at', 'kind']).doNothing())
        .execute();
    }

    // Scoring and the API read status through the catalogue cache.
    this.xstocks.invalidate();

    const byMint = new Map(statuses.map((s) => [s.mint, s]));
    for (const { mint, kind } of anomalies) {
      const status = byMint.get(mint);
      if (kind !== 'status' || !status || status.eligible) continue;
      await this.warnCaptains(mint, rows.find((r) => r.mint === mint)?.symbol ?? mint, status.reason);
    }
    return { notScoring: statuses.filter((s) => !s.eligible).length };
  }

  /**
   * "Your captain isn't scoring": the armband doubles nothing on a price that
   * can't be trusted, so the Managers who gave it one hear about it once.
   */
  private async warnCaptains(mint: string, symbol: string, reason: NotScoringReason | null): Promise<void> {
    const captains = await this.db
      .selectFrom('rosters')
      .innerJoin('roster_slots', (join) =>
        join
          .onRef('roster_slots.roster_id', '=', 'rosters.id')
          .onRef('roster_slots.slot_index', '=', 'rosters.captain_slot'),
      )
      .innerJoin('users', 'users.id', 'rosters.user_id')
      .select(['rosters.user_id as user_id', 'rosters.sport_mode as mode'])
      .where('roster_slots.token_mint', '=', mint)
      .where('users.is_seed', '=', false)
      .execute();
    const why = reason ? NOT_SCORING_LABELS[reason] : 'unreliable price';
    await this.notifications.pushMany(
      captains.map((c) => ({
        userId: c.user_id,
        kind: 'not_scoring' as const,
        title: `Your captain isn't scoring: ${why}`,
        body:
          `${symbol} banks nothing until its price has been reliable for a day. ` +
          'Hand the armband to another pick?',
        data: { mode: c.mode, mint },
      })),
    );
  }
}

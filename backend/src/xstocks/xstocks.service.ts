import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import type { PriceInfo } from '../core/chain.service.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { XStockRow } from '../core/db-types.js';
import { PRICE_SOURCE } from '../core/sources.js';
import type { PriceSource } from '../core/sources.js';
import type { XStockDto } from '../domain/dto.js';
import { NOT_SCORING_LABELS } from '../scoring/engine/eligibility.js';
import type { NotScoringReason } from '../scoring/engine/eligibility.js';

const CACHE_TTL_MS = 5 * 60_000;

/** A listing plus whether it's scoring right now. */
export type CatalogueRow = XStockRow & {
  /** Why it isn't scoring (a NotScoringReason), or null when it is. */
  not_scoring: string | null;
};

@Injectable()
export class XStocksService {
  private cache?: { at: number; rows: CatalogueRow[] };

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
  ) {}

  /** Drops the cache so the next read sees a just-refreshed catalogue. */
  invalidate(): void {
    this.cache = undefined;
  }

  async rows(): Promise<CatalogueRow[]> {
    if (this.cache && Date.now() - this.cache.at < CACHE_TTL_MS) {
      return this.cache.rows;
    }
    const rows = await this.db
      .selectFrom('xstocks')
      .leftJoin('asset_scoring_status as status', 'status.mint', 'xstocks.mint')
      .selectAll('xstocks')
      .select(
        sql<string | null>`case when status.eligible = false then status.reason end`.as(
          'not_scoring',
        ),
      )
      .orderBy('xstocks.symbol')
      .execute();
    this.cache = { at: Date.now(), rows };
    return rows;
  }

  async byMint(): Promise<Map<string, CatalogueRow>> {
    return new Map((await this.rows()).map((r) => [r.mint, r]));
  }

  /** Assets that aren't scoring, by mint, with a reason Managers can read. */
  async notScoring(): Promise<Record<string, string>> {
    return Object.fromEntries(
      (await this.rows()).flatMap((r) => (r.not_scoring ? [[r.mint, notScoringLabel(r.not_scoring)]] : [])),
    );
  }

  async list(): Promise<XStockDto[]> {
    const rows = await this.rows();
    const prices = await this.prices.getPrices(rows.map((r) => r.mint));
    return rows.map((r) => this.toDto(r, prices.get(r.mint)));
  }

  toDto(row: XStockRow & { not_scoring?: string | null }, price?: PriceInfo): XStockDto {
    return {
      symbol: row.symbol,
      companyName: row.company_name,
      mint: row.mint,
      tier: row.tier,
      priceUsd: price?.usdPrice ?? 0,
      change24hPct: price?.priceChange24h ?? 0,
      logoUrl: row.logo_url,
      notScoring: row.not_scoring ? notScoringLabel(row.not_scoring) : null,
    };
  }
}

function notScoringLabel(reason: string): string {
  return NOT_SCORING_LABELS[reason as NotScoringReason] ?? reason.replaceAll('_', ' ');
}

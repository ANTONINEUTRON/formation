import { Inject, Injectable } from '@nestjs/common';
import type { PriceInfo } from '../core/chain.service.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { XStockRow } from '../core/db-types.js';
import { PRICE_SOURCE } from '../core/sources.js';
import type { PriceSource } from '../core/sources.js';
import type { XStockDto } from '../domain/dto.js';

const CACHE_TTL_MS = 5 * 60_000;

@Injectable()
export class XStocksService {
  private cache?: { at: number; rows: XStockRow[] };

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
  ) {}

  /** Drops the cache so the next read sees a just-refreshed catalogue. */
  invalidate(): void {
    this.cache = undefined;
  }

  async rows(): Promise<XStockRow[]> {
    if (this.cache && Date.now() - this.cache.at < CACHE_TTL_MS) {
      return this.cache.rows;
    }
    const rows = await this.db.selectFrom('xstocks').selectAll().orderBy('symbol').execute();
    this.cache = { at: Date.now(), rows };
    return rows;
  }

  async byMint(): Promise<Map<string, XStockRow>> {
    return new Map((await this.rows()).map((r) => [r.mint, r]));
  }

  async list(): Promise<XStockDto[]> {
    const rows = await this.rows();
    const prices = await this.prices.getPrices(rows.map((r) => r.mint));
    return rows.map((r) => this.toDto(r, prices.get(r.mint)));
  }

  toDto(row: XStockRow, price?: PriceInfo): XStockDto {
    return {
      symbol: row.symbol,
      companyName: row.company_name,
      mint: row.mint,
      tier: row.tier,
      priceUsd: price?.usdPrice ?? 0,
      change24hPct: price?.priceChange24h ?? 0,
      logoUrl: row.logo_url,
    };
  }
}

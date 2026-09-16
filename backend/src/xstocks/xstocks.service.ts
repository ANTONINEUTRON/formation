import { Injectable } from '@nestjs/common';
import { ChainService, PriceInfo } from '../core/chain.service.js';
import { DbService, unwrap } from '../core/db.service.js';
import { XStockDto } from '../domain/dto.js';
import { RiskTier } from '../domain/sport.js';

export interface XStockRow {
  mint: string;
  symbol: string;
  company_name: string;
  tier: RiskTier;
  decimals: number;
  logo_url: string | null;
}

const CACHE_TTL_MS = 5 * 60_000;

@Injectable()
export class XStocksService {
  private cache?: { at: number; rows: XStockRow[] };

  constructor(
    private readonly db: DbService,
    private readonly chain: ChainService,
  ) {}

  async rows(): Promise<XStockRow[]> {
    if (this.cache && Date.now() - this.cache.at < CACHE_TTL_MS) {
      return this.cache.rows;
    }
    const rows: XStockRow[] = unwrap(
      await this.db.supabase.from('xstocks').select('*').order('symbol'),
    );
    this.cache = { at: Date.now(), rows };
    return rows;
  }

  async byMint(): Promise<Map<string, XStockRow>> {
    return new Map((await this.rows()).map((r) => [r.mint, r]));
  }

  async list(): Promise<XStockDto[]> {
    const rows = await this.rows();
    const prices = await this.chain.getPrices(rows.map((r) => r.mint));
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

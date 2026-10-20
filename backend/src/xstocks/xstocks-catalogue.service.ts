import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { sql } from 'kysely';
import { SchedulerRegistry } from '@nestjs/schedule';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { StockIssuer } from '../core/db-types.js';
import type { RiskTier } from '../domain/sport.js';
import { tickerOf } from '../domain/sectors.js';
import { fixedTier, NEW_LISTING_TIER } from '../domain/tiers.js';
import { XSTOCKS_SEED } from './xstocks.seed.js';
import { XStocksService } from './xstocks.service.js';

/**
 * Backed Finance's mint authority. Every genuine xStock is minted by it.
 *
 * This is a security filter, not a quality one, and it is always applied. The
 * name "… xStock" is trivially copied, so matching on it alone would let anyone
 * mint `AAPLx` against a pool they control and have us list it as Apple.
 */
const BACKED_MINT_AUTHORITY = '7pt9tkctJPK7PPNQJ77GKg8ZffSF6QxoMiCFYHxrtaCj';

/** Jupiter caps this endpoint at 100 results; `offset` is not honoured. */
const SEARCH_LIMIT = 100;

interface JupiterToken {
  id: string;
  name: string;
  symbol: string;
  icon?: string;
  decimals: number;
  mintAuthority?: string;
  isVerified?: boolean;
  liquidity?: number;
  mcap?: number;
}

/** A listing from either source, in the shape the table wants. */
export interface Listing {
  mint: string;
  symbol: string;
  companyName: string;
  decimals: number;
  logoUrl: string | null;
  liquidity: number;
  issuer: StockIssuer;
}

/** The parts of Backpack's /api/v1/assets read here. */
interface BackpackAsset {
  symbol?: string;
  displayName?: string;
  tokens?: { blockchain?: string; contractAddress?: string; nativeDecimals?: number }[];
}

/** Backpack lists US stocks as "AAPL.US"; the app shows the ticker. */
const BACKPACK_SUFFIX = '.US';

/** Mints per Jupiter price request. */
const PRICE_BATCH = 50;

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * `symbol` is unique in the table, so two mints claiming one ticker would fail
 * the whole upsert. Keep the deeper pool and drop the other.
 */
export function uniqueSymbols(listings: Listing[]): Listing[] {
  const bySymbol = new Map<string, Listing>();
  for (const t of listings) {
    const seen = bySymbol.get(t.symbol);
    if (!seen || t.liquidity > seen.liquidity) bySymbol.set(t.symbol, t);
  }
  return [...bySymbol.values()];
}

/** Starting tiers for the original catalogue, keyed by symbol, until the formula runs. */
const SEED_TIERS = new Map<string, RiskTier>(XSTOCKS_SEED.map((s) => [s.symbol, s.tier]));

export interface RefreshResult {
  fetched: number;
  rejected: number;
  upserted: number;
}

/**
 * Keeps the `xstocks` table in step with the xStocks Jupiter actually lists.
 *
 * Rows are only ever inserted or updated, never deleted. A stock can vanish
 * from Jupiter's search — thin liquidity, a transient outage — while players
 * still hold it and have points riding on it, and dropping the row would strand
 * those positions. A stale row is harmless by comparison: it simply stops
 * getting a fresh price.
 */
@Injectable()
export class XStocksCatalogueService implements OnModuleInit {
  private readonly logger = new Logger(XStocksCatalogueService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    private readonly xstocks: XStocksService,
    private readonly scheduler: SchedulerRegistry,
  ) {}

  async onModuleInit(): Promise<void> {
    // An empty catalogue means /xstocks returns nothing and the app has no
    // stocks to show, so fill it at boot rather than waiting for the interval.
    // Failing here must not stop the server: without this the API would refuse
    // to start whenever Jupiter is briefly unreachable.
    const [{ count, backpack }] = await this.db
      .selectFrom('xstocks')
      .select((eb) => [
        eb.fn.countAll<number>().as('count'),
        eb.fn.countAll<number>().filterWhere('issuer', '=', 'backpack').as('backpack'),
      ])
      .execute();
    // Also when Backpack is switched on but none of its stocks are listed yet,
    // as on the first start after the migration that added them.
    const needBackpack = this.config.backpackApiUrl !== '' && Number(backpack) === 0;
    if (Number(count) === 0 || needBackpack) {
      this.logger.log(
        Number(count) === 0 ? 'Catalogue is empty, populating it now' : 'Listing Backpack stocks now',
      );
      await this.refresh().catch((e) =>
        this.logger.error(`Initial catalogue refresh failed: ${String(e)}`),
      );
    }

    const hours = this.config.catalogueRefreshHours;
    if (hours <= 0) {
      this.logger.log('Catalogue auto-refresh disabled (CATALOGUE_REFRESH_HOURS=0)');
      return;
    }
    const interval = setInterval(
      () => {
        this.refresh().catch((e) => this.logger.error(`Catalogue refresh failed: ${String(e)}`));
      },
      hours * 60 * 60_000,
    );
    this.scheduler.addInterval('xstocks-catalogue-refresh', interval);
  }

  async refresh(): Promise<RefreshResult> {
    const tokens = await this.fetch();
    const xstocks = this.accept(tokens).map(
      (t): Listing => ({
        mint: t.id,
        symbol: t.symbol,
        companyName: companyNameOf(t),
        decimals: t.decimals,
        logoUrl: t.icon ?? null,
        liquidity: t.liquidity ?? 0,
        issuer: 'xstocks',
      }),
    );
    // Backpack is a second source: if it's down, xStocks still refresh.
    const backpack = await this.backpack().catch((e: unknown) => {
      this.logger.warn(`Backpack listings failed: ${String(e)}`);
      return { candidates: 0, listings: [] as Listing[] };
    });
    const fetched = tokens.length + backpack.candidates;
    const accepted = uniqueSymbols([...xstocks, ...backpack.listings]);
    const rejected = fetched - accepted.length;

    if (accepted.length === 0) {
      // Never blank the catalogue because a request went wrong.
      this.logger.warn(`Catalogue refresh found no usable stocks in ${fetched} results`);
      return { fetched, rejected, upserted: 0 };
    }

    const tiers = await this.assignTiers(accepted);
    const rows = accepted.flatMap((t) => {
      const tier = tiers.get(t.mint);
      // Cannot happen — assignTiers covers every listing — but the column only
      // accepts the three tiers, and widening it to string to satisfy the
      // compiler would let a bad value reach a check constraint at runtime.
      if (!tier) return [];
      return [
        {
          mint: t.mint,
          symbol: t.symbol,
          company_name: t.companyName,
          tier,
          // Read from the mint, never assumed: the scale is what converts a
          // quote into shares, so a wrong value misreports what a player buys.
          decimals: t.decimals,
          logo_url: t.logoUrl,
          issuer: t.issuer,
        },
      ];
    });

    await this.db
      .insertInto('xstocks')
      .values(rows)
      .onConflict((oc) =>
        oc.column('mint').doUpdateSet((eb) => ({
          symbol: eb.ref('excluded.symbol'),
          company_name: eb.ref('excluded.company_name'),
          decimals: eb.ref('excluded.decimals'),
          // Keep an icon we had if this source has none.
          logo_url: sql<string | null>`coalesce(excluded.logo_url, xstocks.logo_url)`,
          // asset_class isn't touched either: it's set once, by whoever lists
          // a new kind of asset. And tier is deliberately not updated: the tier formula owns it
          // from here (TiersService), once a season.
        })),
      )
      .execute();

    this.xstocks.invalidate();
    this.logger.log(
      `Catalogue refreshed: ${xstocks.length} xStocks and ${backpack.listings.length} Backpack stocks ` +
        `upserted, ${rejected} rejected`,
    );
    return { fetched, rejected, upserted: rows.length };
  }

  /**
   * Backpack Securities' stocks: every `.US` asset in Backpack's own asset list
   * with a Solana mint, kept when Jupiter prices it with enough liquidity
   * (which also means it can be bought in the app). The list is Backpack's,
   * so a lookalike token can't get in; each stock has its own mint authority,
   * so there's no single authority to check as there is for xStocks.
   */
  private async backpack(): Promise<{ candidates: number; listings: Listing[] }> {
    const base = this.config.backpackApiUrl.replace(/\/$/, '');
    if (!base) return { candidates: 0, listings: [] };
    const res = await fetch(`${base}/api/v1/assets`);
    if (!res.ok) throw new Error(`Backpack assets failed: ${res.status}`);
    const body: unknown = await res.json();
    if (!Array.isArray(body)) throw new Error('Backpack assets did not return a list');

    const candidates = (body as BackpackAsset[]).flatMap((a) => {
      if (typeof a.symbol !== 'string' || !a.symbol.endsWith(BACKPACK_SUFFIX)) return [];
      const token = a.tokens?.find(
        (t) => t.blockchain === 'Solana' && typeof t.contractAddress === 'string' && t.contractAddress.length > 30,
      );
      const decimals = token?.nativeDecimals;
      if (!token?.contractAddress || decimals === undefined || !Number.isInteger(decimals) || decimals < 0) {
        return [];
      }
      return [{ asset: a, symbol: a.symbol, mint: token.contractAddress, decimals }];
    });

    const [depth, icons] = await Promise.all([
      this.jupiterLiquidity(candidates.map((c) => c.mint)),
      this.backpackIcons(),
    ]);
    const floor = this.config.catalogueMinLiquidityUsd;
    const listings = candidates.flatMap(({ asset, symbol: assetSymbol, mint, decimals }): Listing[] => {
      const liquidity = depth.get(mint);
      if (liquidity === undefined || liquidity < floor) return [];
      const symbol = assetSymbol.slice(0, -BACKPACK_SUFFIX.length);
      return [
        {
          mint,
          symbol,
          companyName: (asset.displayName ?? '').trim() || symbol,
          decimals,
          logoUrl: icons.get(mint) ?? null,
          liquidity,
          issuer: 'backpack',
        },
      ];
    });
    return { candidates: candidates.length, listings };
  }

  /** Pool liquidity Jupiter reports for each mint it can price; unpriced mints are absent. */
  private async jupiterLiquidity(mints: string[]): Promise<Map<string, number>> {
    const out = new Map<string, number>();
    // Keyless access allows about a request a second.
    const spacing = 'x-api-key' in this.config.jupiterHeaders ? 0 : 1_100;
    for (let i = 0; i < mints.length; i += PRICE_BATCH) {
      if (i > 0 && spacing) await sleep(spacing);
      const batch = mints.slice(i, i + PRICE_BATCH);
      const url = `${this.config.jupiterApiUrl}/price/v3?ids=${batch.join(',')}`;
      let res = await fetch(url, { headers: this.config.jupiterHeaders });
      if (res.status === 429) {
        await sleep(2_000);
        res = await fetch(url, { headers: this.config.jupiterHeaders });
      }
      // A batch that fails is tried again on the next refresh.
      if (!res.ok) continue;
      const prices = (await res.json()) as Record<string, { usdPrice?: number; liquidity?: number } | null>;
      for (const mint of batch) {
        const p = prices[mint];
        if (p?.usdPrice) out.set(mint, p.liquidity ?? 0);
      }
    }
    return out;
  }

  /** Icons from Jupiter's token search, which knows most Backpack stocks. */
  private async backpackIcons(): Promise<Map<string, string>> {
    const res = await fetch(
      `${this.config.jupiterApiUrl}/tokens/v2/search?query=${encodeURIComponent('Backpack Securities')}` +
        `&limit=${String(SEARCH_LIMIT)}`,
      { headers: this.config.jupiterHeaders },
    ).catch(() => null);
    if (!res?.ok) return new Map();
    const body = (await res.json()) as JupiterToken[];
    return new Map(Array.isArray(body) ? body.flatMap((t) => (t.icon ? [[t.id, t.icon] as const] : [])) : []);
  }

  private async fetch(): Promise<JupiterToken[]> {
    const url =
      `${this.config.jupiterApiUrl}/tokens/v2/search` +
      `?query=xStock&limit=${String(SEARCH_LIMIT)}`;
    const res = await fetch(url, { headers: this.config.jupiterHeaders });
    if (!res.ok) {
      throw new Error(`Jupiter token search failed: ${res.status} ${await res.text()}`);
    }
    const body: unknown = await res.json();
    if (!Array.isArray(body)) throw new Error('Jupiter token search did not return a list');
    return body as JupiterToken[];
  }

  /** Keeps the tokens we are willing to let players buy. */
  private accept(tokens: JupiterToken[]): JupiterToken[] {
    const floor = this.config.catalogueMinLiquidityUsd;
    const kept = tokens.filter(
      (t) =>
        t.mintAuthority === BACKED_MINT_AUTHORITY &&
        t.isVerified !== false &&
        typeof t.id === 'string' &&
        typeof t.symbol === 'string' &&
        Number.isInteger(t.decimals) &&
        t.decimals >= 0 &&
        (t.liquidity ?? 0) >= floor,
    );

    return kept;
  }

  /**
   * The tier a stock starts with when it's first listed. Tiers decide which
   * slots a stock can fill, and the real decision is the tier formula
   * (TiersService), which measures beta and volatility once there's enough
   * price history. Until then: what kind of fund it is, if that settles it,
   * then the seed's starting tier, then balanced. Pool liquidity says how
   * easy a stock is to trade, not how risky it is, so it plays no part.
   */
  private async assignTiers(listings: Listing[]): Promise<Map<string, RiskTier>> {
    // A Backpack stock starts where the same company's xStock already plays.
    const existing = await this.db.selectFrom('xstocks').select(['symbol', 'tier']).execute();
    const byTicker = new Map(existing.map((r) => [tickerOf(r.symbol), r.tier]));
    return new Map(
      listings.map((t) => [
        t.mint,
        fixedTier(t.symbol, t.companyName) ??
          SEED_TIERS.get(t.symbol) ??
          byTicker.get(tickerOf(t.symbol)) ??
          NEW_LISTING_TIER,
      ]),
    );
  }

}

/** "Apple xStock" is the token's name; the company is "Apple". */
function companyNameOf(token: JupiterToken): string {
  return token.name.replace(/\s*xStock$/i, '').trim() || token.symbol;
}

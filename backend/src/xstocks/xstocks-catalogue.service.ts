import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { RISK_TIERS } from '../domain/sport.js';
import type { RiskTier } from '../domain/sport.js';
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

/** Tiers chosen by hand for the original catalogue, keyed by symbol. */
const CURATED_TIERS = new Map<string, RiskTier>(XSTOCKS_SEED.map((s) => [s.symbol, s.tier]));

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
    const [{ count }] = await this.db
      .selectFrom('xstocks')
      .select((eb) => eb.fn.countAll<number>().as('count'))
      .execute();
    if (Number(count) === 0) {
      this.logger.log('Catalogue is empty, populating it now');
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
    const accepted = this.accept(tokens);
    const rejected = tokens.length - accepted.length;

    if (accepted.length === 0) {
      // Never blank the catalogue because a request went wrong.
      this.logger.warn(`Catalogue refresh found no usable xStocks in ${tokens.length} results`);
      return { fetched: tokens.length, rejected, upserted: 0 };
    }

    const tiers = this.assignTiers(accepted);
    const rows = accepted.flatMap((t) => {
      const tier = tiers.get(t.id);
      // Cannot happen — assignTiers covers every token — but the column only
      // accepts the five tiers, and widening it to string to satisfy the
      // compiler would let a bad value reach a check constraint at runtime.
      if (!tier) return [];
      return [
        {
          mint: t.id,
          symbol: t.symbol,
          company_name: companyNameOf(t),
          tier,
          // Read from the mint, never assumed: the scale is what converts a
          // quote into shares, so a wrong value misreports what a player buys.
          decimals: t.decimals,
          logo_url: t.icon ?? null,
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
          logo_url: eb.ref('excluded.logo_url'),
          // tier is deliberately not updated: it is game balance, and a stock
          // silently changing tier would invalidate rosters built around it.
        })),
      )
      .execute();

    this.xstocks.invalidate();
    this.logger.log(
      `Catalogue refreshed: ${accepted.length} xStocks upserted, ${rejected} rejected`,
    );
    return { fetched: tokens.length, rejected, upserted: accepted.length };
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

    // `symbol` is unique in the table, so two mints claiming one ticker would
    // fail the whole upsert. Keep the deeper pool and drop the other.
    const bySymbol = new Map<string, JupiterToken>();
    for (const t of kept) {
      const seen = bySymbol.get(t.symbol);
      if (!seen || (t.liquidity ?? 0) > (seen.liquidity ?? 0)) bySymbol.set(t.symbol, t);
    }
    return [...bySymbol.values()];
  }

  /**
   * Tiers decide which roster slots a stock can fill, so they are game balance
   * rather than a property of the stock.
   *
   * The original thirty were placed by hand and those placements are kept —
   * market cap cannot reproduce them, since Tesla is a mega-cap that plays as
   * momentum. Everything else is banded by pool liquidity, deepest into
   * blue_chip.
   *
   * Liquidity rather than market cap, deliberately. Market cap here is price
   * times supply, and a stock with a near-empty pool has a meaningless price —
   * PayPal's xStock quotes at six figures — so ranking on it sorts precisely the
   * least trustworthy stocks into the most valuable anchor slots. Liquidity is
   * measured money in a pool: harder to distort, and it lines up with what the
   * tiers are meant to express, since a deep pool really is the steadier pick.
   */
  private assignTiers(tokens: JupiterToken[]): Map<string, RiskTier> {
    const tiers = new Map<string, RiskTier>();
    const uncurated: JupiterToken[] = [];

    for (const t of tokens) {
      const curated = CURATED_TIERS.get(t.symbol);
      if (curated) tiers.set(t.id, curated);
      else uncurated.push(t);
    }

    uncurated.sort((a, b) => (b.liquidity ?? 0) - (a.liquidity ?? 0));
    const band = Math.ceil(uncurated.length / RISK_TIERS.length) || 1;
    uncurated.forEach((t, i) => {
      tiers.set(t.id, RISK_TIERS[Math.min(Math.floor(i / band), RISK_TIERS.length - 1)]);
    });
    return tiers;
  }
}

/** "Apple xStock" is the token's name; the company is "Apple". */
function companyNameOf(token: JupiterToken): string {
  return token.name.replace(/\s*xStock$/i, '').trim() || token.symbol;
}

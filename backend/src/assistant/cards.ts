import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { RosterDto, XStockDto } from '../domain/dto.js';
import { sanitizeHtmlCard } from './html-card.js';
import type { HtmlCardDto } from './html-card.js';
import type { SearchSource } from './llm.js';

/** At most this many cards per reply. */
const MAX_CARDS = 2;
const MAX_COMPARE = 4;

/** Chart ranges, each bucketed to roughly sixty points. */
const RANGES = {
  '1D': { ms: 24 * 3_600_000, bucketS: 30 * 60 },
  '7D': { ms: 7 * 24 * 3_600_000, bucketS: 3 * 3_600 },
  '30D': { ms: 30 * 24 * 3_600_000, bucketS: 12 * 3_600 },
} as const;
type Range = keyof typeof RANGES;

/** One line on a chart: % change from the start of the range, at epoch-ms times. */
export interface Series {
  symbol: string;
  points: [number, number][];
}
export type SeriesSet = Record<Range, Series[]>;

export type CardDto =
  | HtmlCardDto
  | {
      type: 'statBoard';
      symbol: string;
      name: string;
      tier: string;
      logoUrl: string | null;
      priceUsd: number;
      change24hPct: number;
      /** Null when the Manager doesn't hold it. */
      sharesHeld: number | null;
      valueUsd: number | null;
      /** Its position in the lineup, if it plays. */
      position: string | null;
      return7dPct: number | null;
      benchmark7dPct: number | null;
      alpha7dPct: number | null;
      chart: SeriesSet;
      news?: { summary: string; sources: SearchSource[] };
    }
  | {
      type: 'compare';
      items: { symbol: string; name: string; tier: string; priceUsd: number; change24hPct: number; return7dPct: number | null }[];
      chart: SeriesSet;
    }
  | {
      type: 'squadBubbles';
      bubbles: { symbol: string; tier: string; position: string; valueUsd: number; alphaPct: number | null }[];
    }
  | {
      type: 'pointsBreakdown';
      bars: { symbol: string; position: string; points: number }[];
      teamPoints: number;
      total: number;
    };

/** What the model may ask for. It picks the card and the stocks; we supply every number. */
export const CARD_REQUEST_SCHEMA = {
  type: 'array',
  items: {
    type: 'object',
    properties: {
      type: { type: 'string', enum: ['statBoard', 'compare', 'squadBubbles', 'pointsBreakdown', 'html'] },
      symbols: { type: 'array', items: { type: 'string' } },
      // Only for type "html".
      title: { type: 'string' },
      html: { type: 'string' },
      height: { type: 'integer' },
    },
    required: ['type'],
  },
} as const;

export interface CardFacts {
  roster: RosterDto;
  stocks: XStockDto[];
  held: Map<string, number>;
}

/**
 * Builds the interactive cards a reply asked for.
 *
 * The model only says "a stat board for AAPLx" — never a price or a return.
 * Everything drawn on a card comes from the catalogue, the price history and
 * the Manager's own roster, so a chart can't show an invented number.
 */
@Injectable()
export class CardsService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  async build(raw: unknown, facts: CardFacts): Promise<CardDto[]> {
    if (!Array.isArray(raw)) return [];
    const bySymbol = new Map(facts.stocks.map((s) => [s.symbol.toUpperCase(), s]));
    const pick = (symbols: unknown) =>
      (Array.isArray(symbols) ? symbols : [])
        .map((s) => (typeof s === 'string' ? bySymbol.get(s.trim().toUpperCase()) : undefined))
        .filter((s): s is XStockDto => s !== undefined)
        .filter((s, i, all) => all.findIndex((t) => t.mint === s.mint) === i);

    const cards: CardDto[] = [];
    const seen = new Set<string>();
    for (const item of raw) {
      if (cards.length >= MAX_CARDS) break;
      const request = (item ?? {}) as Record<string, unknown>;
      const stocks = pick(request.symbols);
      let card: CardDto | null = null;
      switch (request.type) {
        case 'statBoard':
          if (stocks[0]) card = await this.statBoard(stocks[0], facts);
          break;
        case 'compare':
          if (stocks.length >= 2) card = await this.compare(stocks.slice(0, MAX_COMPARE));
          break;
        case 'squadBubbles':
          card = this.squadBubbles(facts);
          break;
        case 'pointsBreakdown':
          card = this.pointsBreakdown(facts);
          break;
        case 'html':
          card = sanitizeHtmlCard(request);
          break;
      }
      const key = card ? `${card.type}:${stocks.map((s) => s.mint).join(',')}` : '';
      if (card && !seen.has(key)) {
        seen.add(key);
        cards.push(card);
      }
    }
    return cards;
  }

  private async statBoard(stock: XStockDto, facts: CardFacts): Promise<CardDto> {
    const chart = await this.chart([stock.mint]);
    const ret = lastPoint(chart['7D'], stock.symbol);
    const bench = lastPoint(chart['7D'], BENCHMARK_LABEL);
    const shares = facts.held.get(stock.mint) ?? 0;
    const slot = facts.roster.slots.find((s) => s.stock?.mint === stock.mint);
    return {
      type: 'statBoard',
      symbol: stock.symbol,
      name: stock.companyName,
      tier: stock.tier,
      logoUrl: stock.logoUrl,
      priceUsd: stock.priceUsd,
      change24hPct: stock.change24hPct,
      sharesHeld: shares > 0 ? shares : null,
      valueUsd: shares > 0 ? round(shares * stock.priceUsd) : null,
      position: slot?.positionLabel ?? null,
      return7dPct: ret,
      benchmark7dPct: bench,
      alpha7dPct: ret !== null && bench !== null ? round(ret - bench) : null,
      chart,
    };
  }

  private async compare(stocks: XStockDto[]): Promise<CardDto> {
    const chart = await this.chart(stocks.map((s) => s.mint));
    return {
      type: 'compare',
      items: stocks.map((s) => ({
        symbol: s.symbol,
        name: s.companyName,
        tier: s.tier,
        priceUsd: s.priceUsd,
        change24hPct: s.change24hPct,
        return7dPct: lastPoint(chart['7D'], s.symbol),
      })),
      chart,
    };
  }

  private squadBubbles({ roster }: CardFacts): CardDto | null {
    const scores = new Map((roster.session?.slots ?? []).map((s) => [s.slotIndex, s]));
    const bubbles = roster.slots.flatMap((slot) => {
      if (!slot.stock) return [];
      const score = scores.get(slot.slotIndex);
      return [
        {
          symbol: slot.stock.symbol,
          tier: slot.stock.tier,
          position: slot.positionLabel,
          valueUsd: round(slot.balance * slot.stock.priceUsd),
          alphaPct: score ? round(score.alpha * 100) : null,
        },
      ];
    });
    return bubbles.length > 0 ? { type: 'squadBubbles', bubbles } : null;
  }

  private pointsBreakdown({ roster }: CardFacts): CardDto | null {
    const session = roster.session;
    if (!session || session.slots.length === 0) return null;
    const teamPoints = round(session.teamEvents.reduce((sum, e) => sum + e.points, 0));
    return {
      type: 'pointsBreakdown',
      bars: session.slots.map((s) => ({ symbol: s.symbol, position: s.role, points: s.total })),
      teamPoints,
      total: session.points,
    };
  }

  /** % change series for [mints] plus the benchmark, for every range. */
  private async chart(mints: string[]): Promise<SeriesSet> {
    const benchmark = this.config.benchmarkMint;
    const symbols = new Map(
      (
        await this.db
          .selectFrom('xstocks')
          .select(['mint', 'symbol'])
          .where('mint', 'in', [...mints, benchmark])
          .execute()
      ).map((r) => [r.mint, r.symbol]),
    );
    const now = this.clock.now();
    const entries = await Promise.all(
      (Object.keys(RANGES) as Range[]).map(async (range) => {
        const { ms, bucketS } = RANGES[range];
        const rows = await sql<{ mint: string; at: Date; price: number }>`
          select mint, max(captured_at) as at,
                 (array_agg(price_usd order by captured_at desc))[1] as price
          from price_ticks
          where mint in (${sql.join([...mints, benchmark])})
            and captured_at >= ${new Date(now - ms)}
          group by mint, floor(extract(epoch from captured_at) / ${bucketS}::numeric)
          order by at
        `.execute(this.db);

        const byMint = new Map<string, { at: number; price: number }[]>();
        for (const row of rows.rows) {
          const list = byMint.get(row.mint) ?? [];
          list.push({ at: new Date(row.at).getTime(), price: Number(row.price) });
          byMint.set(row.mint, list);
        }
        const series: Series[] = [...mints, benchmark].flatMap((mint) => {
          const ticks = byMint.get(mint) ?? [];
          if (ticks.length < 2 || !(ticks[0].price > 0)) return [];
          const base = ticks[0].price;
          return [
            {
              symbol: mint === benchmark ? BENCHMARK_LABEL : (symbols.get(mint) ?? mint),
              points: ticks.map((t): [number, number] => [t.at, round((t.price / base - 1) * 100)]),
            },
          ];
        });
        return [range, series] as const;
      }),
    );
    return Object.fromEntries(entries) as SeriesSet;
  }
}

/** The benchmark's line is labelled for people, whatever its symbol in the catalogue. */
export const BENCHMARK_LABEL = 'S&P 500';

function lastPoint(series: Series[], symbol: string): number | null {
  const points = series.find((s) => s.symbol === symbol)?.points;
  return points && points.length > 0 ? points[points.length - 1][1] : null;
}

function round(n: number): number {
  return Math.round(n * 100) / 100;
}

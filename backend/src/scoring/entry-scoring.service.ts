import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { BALANCE_SOURCE, PRICE_SOURCE } from '../core/sources.js';
import type { BalanceSource, PriceSource } from '../core/sources.js';
import { rosterShape } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { priceAt } from './engine/metrics.js';
import { scoreEntry } from './engine/score-entry.js';
import type {
  EntryBreakdown,
  LineupSnapshot,
  PriceBook,
  ScoreParts,
  ScoreWindow,
  SlotExits,
  SnapshotSlot,
} from './engine/types.js';
import { XStocksService } from '../xstocks/xstocks.service.js';

/**
 * Windows up to this long are scored from every tick. Longer ones (custom
 * leagues can run for months) read a per-session summary instead.
 */
const FULL_HISTORY_MS = 8 * 24 * 3_600_000;

/**
 * Turns database state into scoring-engine input: locks lineups, loads price
 * history, and scores an entry. Shared by gameweeks and duels.
 */
@Injectable()
export class EntryScoringService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
    @Inject(BALANCE_SOURCE) private readonly balances: BalanceSource,
    private readonly xstocks: XStocksService,
  ) {}

  window(start: Date, end: Date): ScoreWindow {
    return {
      start: start.getTime(),
      end: end.getTime(),
      sessionMinutes: this.config.sessionMinutes,
    };
  }

  /**
   * Locks a player's current team for a scoring window. Returns null when no
   * slot is filled. A partial team is locked as it stands: empty slots simply
   * aren't in the snapshot, and the engine already scores unheld picks as zero.
   * Whether a team holds enough to be entered is [holdsAny]'s call.
   */
  async lockLineup(
    userId: string,
    wallet: string,
    mode: SportMode,
  ): Promise<LineupSnapshot | null> {
    const roster = await this.db
      .selectFrom('rosters')
      .select(['id', 'formation', 'captain_slot', 'vice_captain_slot'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    if (!roster) return null;

    const slots = await this.db
      .selectFrom('roster_slots')
      .select(['slot_index', 'token_mint'])
      .where('roster_id', '=', roster.id)
      .orderBy('slot_index')
      .execute();
    const shape = rosterShape(mode, roster.formation);
    if (slots.length === 0) return null;

    const stocks = await this.xstocks.byMint();
    const mints = slots.map((s) => s.token_mint);
    const [balances, prices] = await Promise.all([
      this.balances.getBalances(wallet, { fresh: true }),
      this.prices.getPrices([...mints, this.config.benchmarkMint], { fresh: true }),
    ]);

    const snapshotSlots: SnapshotSlot[] = slots.map((slot) => ({
      slotIndex: slot.slot_index,
      role: shape[slot.slot_index]?.label ?? '',
      mint: slot.token_mint,
      symbol: stocks.get(slot.token_mint)?.symbol ?? slot.token_mint,
      startBalance: balances.get(slot.token_mint) ?? 0,
      startPrice: prices.get(slot.token_mint)?.usdPrice ?? 0,
    }));

    return {
      mode,
      formation: roster.formation,
      captainSlot: roster.captain_slot,
      viceCaptainSlot: roster.vice_captain_slot,
      benchmarkPrice: prices.get(this.config.benchmarkMint)?.usdPrice ?? 0,
      slots: snapshotSlots,
    };
  }

  /**
   * True when at least one locked pick is actually held and priced, which is
   * what it takes to be entered: one owned stock in the lineup is enough.
   */
  holdsAny(snapshot: LineupSnapshot): boolean {
    return snapshot.slots.some((slot) => slot.startBalance > 0 && slot.startPrice > 0);
  }

  /** Price history for the window, plus the benchmark. */
  async priceBook(mints: string[], window: ScoreWindow): Promise<PriceBook> {
    const wanted = [...new Set([...mints, this.config.benchmarkMint])];
    if (wanted.length === 0) return new Map();
    const rows =
      window.end - window.start > FULL_HISTORY_MS
        ? await this.sessionTicks(wanted, window)
        : await this.db
            .selectFrom('price_ticks')
            .select(['mint', 'price_usd', 'captured_at'])
            .where('mint', 'in', wanted)
            .where('captured_at', '>=', new Date(window.start))
            .where('captured_at', '<=', new Date(window.end))
            .orderBy('captured_at')
            .execute();

    const book: PriceBook = new Map(wanted.map((mint) => [mint, []]));
    for (const row of rows) {
      book.get(row.mint)?.push({
        at: new Date(row.captured_at).getTime(),
        price: row.price_usd,
      });
    }
    return book;
  }

  /**
   * Two ticks per mint per session: the last one (each session's close) and
   * the lowest one (for drawdown events). The engine only reads prices at
   * session boundaries, at the window end and as a minimum, so for a pick held
   * the whole window this scores exactly as the full history does — on a few
   * hundred rows a year instead of a hundred thousand. Sessions are bucketed
   * as (start, end], so a tick landing on a boundary closes the session it ends.
   */
  private async sessionTicks(mints: string[], window: ScoreWindow) {
    const start = new Date(window.start);
    const sessionSeconds = Math.max(1, window.sessionMinutes) * 60;
    const result = await sql<{ mint: string; price_usd: number; captured_at: Date }>`
      select mint, price_usd, captured_at
      from (
        select mint, price_usd, captured_at,
          row_number() over (partition by mint, bucket order by captured_at desc) as last_rank,
          row_number() over (partition by mint, bucket order by price_usd, captured_at) as low_rank
        from (
          select mint, price_usd, captured_at,
            ceil(extract(epoch from (captured_at - ${start}::timestamptz)) / ${sessionSeconds}::numeric) as bucket
          from price_ticks
          where mint in (${sql.join(mints)})
            and captured_at >= ${start}
            and captured_at <= ${new Date(window.end)}
        ) ticks
      ) ranked
      where last_rank = 1 or low_rank = 1
      order by captured_at
    `.execute(this.db);
    return result.rows;
  }

  /**
   * Scores a locked lineup using balances read now.
   *
   * Picks that have gone to zero since the window opened are recorded as exits
   * and scored up to the last price seen while held. Callers persist the
   * returned [exits] so a sale stays pinned to when it was first observed
   * rather than drifting with later ticks.
   */
  async score(
    snapshot: LineupSnapshot,
    wallet: string,
    window: ScoreWindow,
    {
      fresh = false,
      exits = {},
      parts,
      at = Date.now(),
    }: { fresh?: boolean; exits?: SlotExits; parts?: ScoreParts; at?: number } = {},
  ): Promise<{
    breakdown: EntryBreakdown;
    endBalances: Record<string, number>;
    exits: SlotExits;
  }> {
    const mints = snapshot.slots.map((s) => s.mint);
    const [balances, prices] = await Promise.all([
      this.balances.getBalances(wallet, { fresh }),
      this.priceBook(mints, window),
    ]);
    const endBalances = Object.fromEntries(mints.map((m) => [m, balances.get(m) ?? 0]));
    const observedAt = Math.min(Math.max(at, window.start), window.end);
    const nextExits = this.withExits(snapshot, endBalances, prices, exits, observedAt);

    return {
      endBalances,
      exits: nextExits,
      breakdown: scoreEntry({
        snapshot,
        endBalances,
        prices,
        benchmarkMint: this.config.benchmarkMint,
        window,
        exits: nextExits,
        parts,
      }),
    };
  }

  /**
   * Records an exit for any pick whose balance has reached zero and that isn't
   * already recorded. A partial sale isn't an exit: the remaining shares keep
   * scoring to the end of the window.
   */
  private withExits(
    snapshot: LineupSnapshot,
    endBalances: Record<string, number>,
    prices: PriceBook,
    exits: SlotExits,
    at: number,
  ): SlotExits {
    const next: SlotExits = { ...exits };
    for (const slot of snapshot.slots) {
      if (next[slot.mint] || slot.startBalance <= 0) continue;
      if ((endBalances[slot.mint] ?? 0) > 0) continue;
      next[slot.mint] = {
        at,
        price: priceAt(prices.get(slot.mint) ?? [], at, slot.startPrice),
      };
    }
    return next;
  }
}

import { Inject, Injectable } from '@nestjs/common';
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
   * Locks a player's current team for a scoring window. Returns null when the
   * roster isn't complete, so only full teams are entered.
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
    if (slots.length !== shape.length) return null;

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

  /** Price history for the window, plus the benchmark. */
  async priceBook(mints: string[], window: ScoreWindow): Promise<PriceBook> {
    const wanted = [...new Set([...mints, this.config.benchmarkMint])];
    if (wanted.length === 0) return new Map();
    const rows = await this.db
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

import type { SportMode } from '../../domain/sport.js';

/** One drafted pick as locked at the start of a scoring window. */
export interface SnapshotSlot {
  slotIndex: number;
  /** Role label: GK/DEF/MID/FWD, PG/SG/SF/PF/C, QB/RB/WR/TE/FLEX/K. */
  role: string;
  mint: string;
  symbol: string;
  startBalance: number;
  startPrice: number;
}

/**
 * The lineup a player is scored on for one gameweek or duel. Locked when the
 * window opens, so later roster, formation or captain changes only apply to
 * the next window.
 */
export interface LineupSnapshot {
  mode: SportMode;
  formation: string | null;
  captainSlot: number | null;
  viceCaptainSlot: number | null;
  /** Benchmark (SPYx) price when the window opened. */
  benchmarkPrice: number;
  slots: SnapshotSlot[];
}

export interface PriceTick {
  /** Epoch milliseconds. */
  at: number;
  price: number;
}

/** Ordered price history per mint. */
export type PriceBook = Map<string, PriceTick[]>;

export interface ScoreWindow {
  start: number;
  end: number;
  /** Length of a "day" bucket used by session events. */
  sessionMinutes: number;
}

export interface ScoreInput {
  snapshot: LineupSnapshot;
  /** Balances read at the end of the window, keyed by mint. */
  endBalances: Record<string, number>;
  prices: PriceBook;
  benchmarkMint: string;
  window: ScoreWindow;
}

export interface ScoreEvent {
  code: string;
  label: string;
  points: number;
}

export interface SlotScore {
  slotIndex: number;
  role: string;
  mint: string;
  symbol: string;
  /** False when the pick wasn't held for the whole window: it scores nothing. */
  counted: boolean;
  ownReturn: number;
  alpha: number;
  base: number;
  events: ScoreEvent[];
  /** Captain multiplier: 2 (football), 1.5 (basketball), otherwise 1. */
  multiplier: number;
  total: number;
}

export interface EntryBreakdown {
  total: number;
  slots: SlotScore[];
  teamEvents: ScoreEvent[];
}

export interface SessionReturn {
  start: number;
  end: number;
  open: number;
  close: number;
  /** Fraction, e.g. 0.012 = +1.2%. */
  change: number;
}

/** Everything a sport's rules need about one pick over the window. */
export interface SlotContext {
  role: string;
  ownReturn: number;
  alpha: number;
  startPrice: number;
  /** Lowest price seen in the window as a fraction of the start price. */
  lowestRelative: number;
  sessions: SessionReturn[];
  benchmarkSessions: SessionReturn[];
}

export interface SportRules {
  slotEvents(ctx: SlotContext): ScoreEvent[];
  /** Events scored once for the whole team, e.g. basketball double-doubles. */
  teamEvents?(contexts: SlotContext[]): ScoreEvent[];
}

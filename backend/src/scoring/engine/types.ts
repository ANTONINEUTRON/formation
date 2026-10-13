import type { SportMode } from '../../domain/sport.js';
import type { GuardState } from './guard.js';

/** One drafted pick as locked at the start of a scoring window. */
export interface SnapshotSlot {
  slotIndex: number;
  /** Role label: GK/DEF/MID/FWD, PG/SG/SF/PF/C, QB/RB/WR/TE/FLEX/K. */
  role: string;
  mint: string;
  symbol: string;
  startBalance: number;
  startPrice: number;
  /**
   * The benchmark this pick is measured against, when it isn't the snapshot's
   * (an asset of another class). Absent for US equities.
   */
  benchmarkMint?: string;
  benchmarkPrice?: number;
  /** A jump held on the previous tick, waiting to be confirmed (see guard.ts). */
  pending?: -1 | 0 | 1;
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

/** When a pick was sold, and the last price observed while it was still held. */
export interface SlotExit {
  /** Epoch milliseconds of the tick that first saw the balance fall. */
  at: number;
  price: number;
}

/** Sold picks keyed by mint. */
export type SlotExits = Record<string, SlotExit>;

export interface ScoreInput {
  snapshot: LineupSnapshot;
  /** Balances read at the end of the window, keyed by mint. */
  endBalances: Record<string, number>;
  prices: PriceBook;
  benchmarkMint: string;
  window: ScoreWindow;
  /** Picks sold during the window; they score up to the sale. */
  exits?: SlotExits;
  /**
   * Which halves of the score to compute. Base alpha is banked on every tick;
   * role events need a session-length window to mean anything (a "goal" is a
   * 3% move), so they are rolled up once a day. Defaults to both.
   */
  parts?: ScoreParts;
  /**
   * Picks that aren't scoring, by mint, with the reason. They bank nothing,
   * fire no events and can't carry the armband.
   */
  notScoring?: Record<string, string>;
  /** Hold-and-clamp implausible jumps tick by tick (guard.ts). */
  guard?: { maxMove: number };
  /** Limits on what one pick can bank; the general league sets these. */
  caps?: ScoreCaps;
}

export interface ScoreCaps {
  /** Base points per pick per tick, either way. */
  tickBase?: number;
  /** Base points per pick per session, either way... */
  sessionBase?: number;
  /** ...given what each pick (by mint) has banked so far this session. */
  sessionBaseUsed?: Record<string, number>;
  /** Role-event points per pick per session, either way. */
  sessionEvents?: number;
}

export interface ScoreParts {
  base: boolean;
  events: boolean;
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
  /** False only when the pick was never really held: it scores nothing. */
  counted: boolean;
  /** True when the pick was sold in-window and scored up to the sale price. */
  substituted: boolean;
  ownReturn: number;
  alpha: number;
  base: number;
  events: ScoreEvent[];
  /** Captain multiplier: 2 (football), 1.5 (basketball), otherwise 1. */
  multiplier: number;
  total: number;
  /** Why the pick isn't scoring, e.g. "stale price". Absent when it is. */
  notScoring?: string;
  /** Guard outcome for the window: a jump held, or banked clamped. */
  guard?: { held: boolean; jumps: number; state: GuardState };
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

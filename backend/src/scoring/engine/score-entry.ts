import { captaincyRules } from '../../domain/captaincy.js';
import type { SportMode } from '../../domain/sport.js';
import {
  changeBetween,
  lowestRelative,
  priceAt,
  round1,
  sessionReturns,
} from './metrics.js';
import { americanFootballRules } from './rules/american-football.js';
import { basketballRules } from './rules/basketball.js';
import { footballRules } from './rules/football.js';
import type {
  EntryBreakdown,
  ScoreInput,
  ScoreParts,
  SlotContext,
  SlotScore,
  SportRules,
} from './types.js';

/** Base scoring: 1 point per 0.1% a pick beats the benchmark. */
const POINTS_PER_ALPHA = 1_000;

/**
 * Substitutions per day that cost nothing. Substituting is free for the player
 * and earns the app nothing, so the allowance lives here; transfers (buying and
 * selling) are unlimited and free, because those are the revenue event.
 */
export const FREE_SUBSTITUTIONS_PER_DAY = 3;
/** Points charged for each substitution beyond the daily allowance. */
export const SUBSTITUTION_COST = 4;

const BOTH: ScoreParts = { base: true, events: true };

export function rulesFor(mode: SportMode): SportRules {
  switch (mode) {
    case 'football':
      return footballRules;
    case 'basketball':
      return basketballRules;
    case 'american_football':
      return americanFootballRules;
  }
}

/**
 * Scores one locked lineup over its window (docs/formation-scoring.md §5).
 *
 * - Base points come from alpha against the benchmark, so market direction
 *   doesn't decide the league.
 * - Role events reward what the stock itself did.
 * - Selling a pick in-window substitutes it off: it scores what it earned up
 *   to the sale price and keeps those points. Only a pick that was never held
 *   scores nothing. The replacement starts scoring next window.
 * - Transfers past the free allowance are charged against the total.
 * - The captain's multiplier applies after events; if the captain isn't
 *   counted, football's vice-captain takes it.
 */
export function scoreEntry(input: ScoreInput): EntryBreakdown {
  const {
    snapshot,
    endBalances,
    prices,
    benchmarkMint,
    window,
    exits = {},
    parts = BOTH,
  } = input;
  const rules = rulesFor(snapshot.mode);
  const captaincy = captaincyRules(snapshot.mode);

  const benchmarkTicks = prices.get(benchmarkMint) ?? [];
  const benchmarkClose = priceAt(benchmarkTicks, window.end, snapshot.benchmarkPrice);
  const benchmarkReturn = changeBetween(snapshot.benchmarkPrice, benchmarkClose);
  const benchmarkSessions = sessionReturns(benchmarkTicks, window, snapshot.benchmarkPrice);

  const captainSlot = effectiveCaptain(input);

  const contexts: SlotContext[] = [];
  const slots: SlotScore[] = snapshot.slots.map((slot) => {
    const ticks = prices.get(slot.mint) ?? [];
    const endBalance = endBalances[slot.mint] ?? 0;
    const exit = exits[slot.mint];
    // A sold pick still counts: it is scored up to its exit price. Only a slot
    // that was never funded (no starting balance or no price) scores nothing.
    const held = slot.startBalance > 0 && slot.startPrice > 0;
    const counted = held && (endBalance > 0 || exit !== undefined);

    const base: SlotScore = {
      slotIndex: slot.slotIndex,
      role: slot.role,
      mint: slot.mint,
      symbol: slot.symbol,
      counted,
      substituted: counted && exit !== undefined,
      ownReturn: 0,
      alpha: 0,
      base: 0,
      events: [],
      multiplier: 1,
      total: 0,
    };
    if (!counted) return base;

    // Substituted picks stop at the sale; the rest run to the window end.
    const close = exit ? exit.price : priceAt(ticks, window.end, slot.startPrice);
    const ownReturn = changeBetween(slot.startPrice, close);
    // Events only see the part of the window the pick was actually held for,
    // so a stock's moves after it was sold can't score for its old owner.
    const heldWindow = exit ? { ...window, end: Math.min(exit.at, window.end) } : window;
    const context: SlotContext = {
      role: slot.role,
      ownReturn,
      alpha: ownReturn - benchmarkReturn,
      startPrice: slot.startPrice,
      lowestRelative: lowestRelative(ticks, heldWindow, slot.startPrice),
      sessions: sessionReturns(ticks, heldWindow, slot.startPrice),
      benchmarkSessions,
    };
    contexts.push(context);

    const events = parts.events ? rules.slotEvents(context) : [];
    const basePoints = parts.base ? round1(context.alpha * POINTS_PER_ALPHA) : 0;
    const multiplier = slot.slotIndex === captainSlot ? captaincy.multiplier : 1;
    const eventPoints = events.reduce((sum, e) => sum + e.points, 0);

    return {
      ...base,
      ownReturn,
      alpha: context.alpha,
      base: basePoints,
      events,
      multiplier,
      total: round1((basePoints + eventPoints) * multiplier),
    };
  });

  const teamEvents =
    parts.events && contexts.length > 0 ? (rules.teamEvents?.(contexts) ?? []) : [];
  const total = round1(
    slots.reduce((sum, s) => sum + s.total, 0) +
      teamEvents.reduce((sum, e) => sum + e.points, 0),
  );

  return { total, slots, teamEvents };
}

/** Points charged for [count] substitutions in a day, as a negative number. */
export function substitutionCost(count: number): number {
  const paid = Math.max(0, count - FREE_SUBSTITUTIONS_PER_DAY);
  // Guard against -0, which reads badly in the breakdown and in JSON.
  return paid === 0 ? 0 : -paid * SUBSTITUTION_COST;
}

/** The captain, or the vice-captain when the captain isn't counted. */
function effectiveCaptain({ snapshot, endBalances }: ScoreInput): number | null {
  const counted = (slotIndex: number | null) => {
    if (slotIndex === null) return false;
    const slot = snapshot.slots.find((s) => s.slotIndex === slotIndex);
    if (!slot) return false;
    return Math.min(slot.startBalance, endBalances[slot.mint] ?? 0) > 0 && slot.startPrice > 0;
  };
  if (counted(snapshot.captainSlot)) return snapshot.captainSlot;
  if (counted(snapshot.viceCaptainSlot)) return snapshot.viceCaptainSlot;
  return null;
}

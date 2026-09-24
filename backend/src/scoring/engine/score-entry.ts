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
  SlotContext,
  SlotScore,
  SportRules,
} from './types.js';

/** Base scoring: 1 point per 0.1% a pick beats the benchmark. */
const POINTS_PER_ALPHA = 1_000;

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
 * - A pick not held for the whole window (`min(start, end)` balance is zero)
 *   scores nothing at all.
 * - The captain's multiplier applies after events; if the captain isn't
 *   counted, football's vice-captain takes it.
 */
export function scoreEntry(input: ScoreInput): EntryBreakdown {
  const { snapshot, endBalances, prices, benchmarkMint, window } = input;
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
    const counted = Math.min(slot.startBalance, endBalance) > 0 && slot.startPrice > 0;

    const base: SlotScore = {
      slotIndex: slot.slotIndex,
      role: slot.role,
      mint: slot.mint,
      symbol: slot.symbol,
      counted,
      ownReturn: 0,
      alpha: 0,
      base: 0,
      events: [],
      multiplier: 1,
      total: 0,
    };
    if (!counted) return base;

    const close = priceAt(ticks, window.end, slot.startPrice);
    const ownReturn = changeBetween(slot.startPrice, close);
    const context: SlotContext = {
      role: slot.role,
      ownReturn,
      alpha: ownReturn - benchmarkReturn,
      startPrice: slot.startPrice,
      lowestRelative: lowestRelative(ticks, window, slot.startPrice),
      sessions: sessionReturns(ticks, window, slot.startPrice),
      benchmarkSessions,
    };
    contexts.push(context);

    const events = rules.slotEvents(context);
    const basePoints = round1(context.alpha * POINTS_PER_ALPHA);
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

  const teamEvents = contexts.length > 0 ? (rules.teamEvents?.(contexts) ?? []) : [];
  const total = round1(
    slots.reduce((sum, s) => sum + s.total, 0) +
      teamEvents.reduce((sum, e) => sum + e.points, 0),
  );

  return { total, slots, teamEvents };
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

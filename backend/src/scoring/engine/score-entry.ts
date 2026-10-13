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
import { guardSeries } from './guard.js';
import type {
  EntryBreakdown,
  PriceTick,
  ScoreCaps,
  ScoreEvent,
  ScoreInput,
  ScoreParts,
  SessionReturn,
  SlotContext,
  SlotScore,
  SnapshotSlot,
  SportRules,
} from './types.js';

/** Base scoring: 1 point per 0.1% a pick beats the benchmark. */
const POINTS_PER_ALPHA = 1_000;

/**
 * The general league's limits on one pick (SCORING_PLAN.md §1.3). A tick is at
 * most a 10% relative move after the guard, so the tick cap rarely bites; the
 * session caps stop a single pick running away with a day.
 */
export const GENERAL_CAPS = { tickBase: 100, sessionBase: 150, sessionEvents: 60 } as const;

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
    notScoring = {},
    guard,
    caps,
  } = input;
  const rules = rulesFor(snapshot.mode);
  const captaincy = captaincyRules(snapshot.mode);

  // Most picks share the snapshot's benchmark; an asset of another class
  // carries its own. Each distinct benchmark is worked out once.
  const benchmarks = new Map<string, Benchmark>();
  const benchmarkOf = (slot: SnapshotSlot): Benchmark => {
    const mint = slot.benchmarkMint ?? benchmarkMint;
    const start = slot.benchmarkMint ? (slot.benchmarkPrice ?? 0) : snapshot.benchmarkPrice;
    const key = `${mint}@${start}`;
    let found = benchmarks.get(key);
    if (!found) {
      const ticks = prices.get(mint) ?? [];
      found = {
        start,
        ticks,
        return: changeBetween(start, priceAt(ticks, window.end, start)),
        sessions: sessionReturns(ticks, window, start),
      };
      benchmarks.set(key, found);
    }
    return found;
  };

  const captainSlot = effectiveCaptain(input);

  const contexts: SlotContext[] = [];
  const slots: SlotScore[] = snapshot.slots.map((slot) => {
    let ticks = prices.get(slot.mint) ?? [];
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
    // Kept on the team, but a price that can't be trusted scores nothing.
    const reason = notScoring[slot.mint];
    if (reason) return { ...base, notScoring: reason };

    const benchmark = benchmarkOf(slot);
    let guarded: SlotScore['guard'];
    if (guard) {
      // Ticks after the window opened only: the opening price is the seed.
      const result = guardSeries(
        ticks.filter((t) => t.at > window.start),
        benchmark.ticks,
        { price: slot.startPrice, benchmark: benchmark.start, pending: slot.pending ?? 0 },
        guard.maxMove,
      );
      ticks = result.ticks;
      guarded = { held: result.held, jumps: result.jumps.length, state: result.state };
    }

    // Substituted picks stop at the sale; the rest run to the window end.
    const close = exit
      ? guard
        ? priceAt(ticks, exit.at, slot.startPrice)
        : exit.price
      : priceAt(ticks, window.end, slot.startPrice);
    const ownReturn = changeBetween(slot.startPrice, close);
    // Events only see the part of the window the pick was actually held for,
    // so a stock's moves after it was sold can't score for its old owner.
    const heldWindow = exit ? { ...window, end: Math.min(exit.at, window.end) } : window;
    const context: SlotContext = {
      role: slot.role,
      ownReturn,
      alpha: ownReturn - benchmark.return,
      startPrice: slot.startPrice,
      lowestRelative: lowestRelative(ticks, heldWindow, slot.startPrice),
      sessions: sessionReturns(ticks, heldWindow, slot.startPrice),
      benchmarkSessions: benchmark.sessions,
    };
    contexts.push(context);

    const events = parts.events ? capEvents(rules.slotEvents(context), caps?.sessionEvents) : [];
    const basePoints = parts.base
      ? round1(capBase(context.alpha * POINTS_PER_ALPHA, caps, slot.mint))
      : 0;
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
      ...(guarded ? { guard: guarded } : {}),
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

interface Benchmark {
  start: number;
  ticks: PriceTick[];
  return: number;
  sessions: SessionReturn[];
}

/** Clamps a pick's base points to the per-tick and per-session caps. */
function capBase(points: number, caps: ScoreCaps | undefined, mint: string): number {
  if (!caps) return points;
  let capped = points;
  if (caps.tickBase !== undefined) {
    capped = Math.max(-caps.tickBase, Math.min(caps.tickBase, capped));
  }
  if (caps.sessionBase !== undefined) {
    // Room left this session. Never forces a move the other way, even if a
    // pick somehow banked past the cap already.
    const used = caps.sessionBaseUsed?.[mint] ?? 0;
    const upper = Math.max(0, caps.sessionBase - used);
    const lower = Math.min(0, -caps.sessionBase - used);
    capped = Math.max(lower, Math.min(upper, capped));
  }
  return capped;
}

/**
 * Caps a pick's role events for a session. The events stay listed, and a
 * "Daily cap" line takes off the excess, so the breakdown still adds up.
 */
function capEvents(events: ScoreEvent[], cap: number | undefined): ScoreEvent[] {
  if (cap === undefined) return events;
  const sum = events.reduce((total, e) => total + e.points, 0);
  if (Math.abs(sum) <= cap) return events;
  return [...events, { code: 'cap', label: 'Daily cap', points: round1(Math.sign(sum) * cap - sum) }];
}

/**
 * The captain, or the vice-captain when the captain isn't counted or isn't
 * scoring.
 */
function effectiveCaptain({ snapshot, endBalances, notScoring = {} }: ScoreInput): number | null {
  const counted = (slotIndex: number | null) => {
    if (slotIndex === null) return false;
    const slot = snapshot.slots.find((s) => s.slotIndex === slotIndex);
    if (!slot || notScoring[slot.mint]) return false;
    return Math.min(slot.startBalance, endBalances[slot.mint] ?? 0) > 0 && slot.startPrice > 0;
  };
  if (counted(snapshot.captainSlot)) return snapshot.captainSlot;
  if (counted(snapshot.viceCaptainSlot)) return snapshot.viceCaptainSlot;
  return null;
}

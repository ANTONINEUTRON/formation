import { captaincyRules } from '../domain/captaincy.js';
import { parseFormation } from '../domain/formation.js';
import { slotAccepts } from '../domain/sport.js';
import type { PositionSlot, RiskTier, SportMode } from '../domain/sport.js';
import { substitutionCost } from '../scoring/engine/score-entry.js';

/** At most this many moves per reply; more is noise. */
const MAX_SUGGESTIONS = 3;

/**
 * A move the Manager can apply with one tap. The model proposes these; every
 * one is checked here against the real roster and the real rules, and anything
 * that wouldn't be accepted by the roster endpoints is dropped rather than
 * shown and left to fail.
 */
export type Suggestion =
  | {
      kind: 'setCaptain';
      slotIndex: number;
      /** For display: the stock in that slot and its position. */
      symbol: string;
      position: string;
      vice: boolean;
      reason: string;
    }
  | {
      kind: 'fillSlot';
      slotIndex: number;
      position: string;
      mint: string;
      symbol: string;
      reason: string;
      /** The wallet doesn't hold it: applying means buying it first. */
      needsPurchase: boolean;
      /** Points this costs: 0 within today's free substitutions, negative beyond. */
      substitutionCost: number;
    }
  | { kind: 'setFormation'; formation: string; reason: string };

export interface RosterFacts {
  mode: SportMode;
  formation: string | null;
  shape: PositionSlot[];
  /** Mint in each filled slot. */
  slots: Map<number, string>;
  captainSlot: number | null;
  viceCaptainSlot: number | null;
  /** Mint -> amount held, positive only. */
  held: Map<string, number>;
  /** Catalogue, by upper-cased symbol. */
  /** A paused stock (not scoring) can't be placed in a slot, so it's never suggested for one. */
  catalogue: Map<string, { mint: string; symbol: string; tier: RiskTier; paused?: boolean }>;
  substitutionsToday: number;
}

/**
 * Turns the model's raw proposals into suggestions that will succeed.
 *
 * Substitutions are charged in order, so the second substitution in a reply
 * is priced as the next one after the first.
 */
export function validateSuggestions(raw: unknown, facts: RosterFacts): Suggestion[] {
  if (!Array.isArray(raw)) return [];
  const rules = captaincyRules(facts.mode);
  const out: Suggestion[] = [];
  const seen = new Set<string>();
  const symbolOf = new Map([...facts.catalogue.values()].map((s) => [s.mint, s.symbol]));
  let substitutions = facts.substitutionsToday;

  for (const item of raw) {
    if (out.length >= MAX_SUGGESTIONS) break;
    if (!item || typeof item !== 'object') continue;
    const s = item as Record<string, unknown>;
    const reason = typeof s.reason === 'string' ? s.reason.trim().slice(0, 200) : '';

    if (s.kind === 'setCaptain') {
      const slotIndex = asIndex(s.slotIndex);
      const vice = s.vice === true;
      if (slotIndex === null || !facts.slots.has(slotIndex)) continue;
      if (vice ? !rules.vice : !rules.captain) continue;
      if ((vice ? facts.viceCaptainSlot : facts.captainSlot) === slotIndex) continue;
      const mint = facts.slots.get(slotIndex) ?? '';
      push(`captain:${vice}`, {
        kind: 'setCaptain',
        slotIndex,
        symbol: symbolOf.get(mint) ?? mint,
        position: facts.shape[slotIndex]?.label ?? '',
        vice,
        reason,
      });
    } else if (s.kind === 'fillSlot') {
      const slotIndex = asIndex(s.slotIndex);
      const position = slotIndex === null ? undefined : facts.shape[slotIndex];
      const stock =
        typeof s.symbol === 'string' ? facts.catalogue.get(s.symbol.trim().toUpperCase()) : undefined;
      if (slotIndex === null || !position || !stock || stock.paused) continue;
      if (!slotAccepts(position, stock.tier)) continue;
      const current = facts.slots.get(slotIndex);
      if (current === stock.mint) continue;
      const elsewhere = [...facts.slots].some(([i, mint]) => mint === stock.mint && i !== slotIndex);
      if (elsewhere || seen.has(`slot:${slotIndex}`)) continue;

      let cost = 0;
      if (current !== undefined) {
        substitutions++;
        cost = substitutionCost(substitutions) - substitutionCost(substitutions - 1);
      }
      push(`slot:${slotIndex}`, {
        kind: 'fillSlot',
        slotIndex,
        position: position.label,
        mint: stock.mint,
        symbol: stock.symbol,
        reason,
        needsPurchase: (facts.held.get(stock.mint) ?? 0) <= 0,
        substitutionCost: cost,
      });
    } else if (s.kind === 'setFormation') {
      if (facts.mode !== 'football') continue;
      let formation: string;
      try {
        formation = parseFormation(s.formation);
      } catch {
        continue;
      }
      if (formation === facts.formation) continue;
      push('formation', { kind: 'setFormation', formation, reason });
    }
  }
  return out;

  function push(key: string, suggestion: Suggestion) {
    if (seen.has(key)) return;
    seen.add(key);
    out.push(suggestion);
  }
}

function asIndex(value: unknown): number | null {
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : null;
}

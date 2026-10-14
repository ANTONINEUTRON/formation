import { captaincyRules } from './captaincy.js';
import type { ManagerHoldingDto, RosterSlotDto } from './dto.js';
import { DEFAULT_FORMATION, rosterShape, slotAccepts } from './sport.js';
import type { SportMode } from './sport.js';

export interface DerivedLineup {
  lineup: RosterSlotDto[];
  formation: string | null;
  captainSlot: number | null;
  viceCaptainSlot: number | null;
}

/**
 * A lineup picked from a wallet's holdings, for players who never drafted
 * (the demo players). Slots with the fewest eligible holdings are filled
 * first, each with the most valuable stock that fits, so a wallet light on
 * one tier still covers it. The most valuable picks get the armbands.
 * Positions nothing fits stay empty.
 */
export function lineupFromHoldings(mode: SportMode, holdings: ManagerHoldingDto[]): DerivedLineup {
  const formation = mode === 'football' ? DEFAULT_FORMATION : null;
  const shape = rosterShape(mode, formation);
  const byValue = [...holdings].sort((a, b) => b.valueUsd - a.valueUsd);
  const fits = (slot: number) => byValue.filter((h) => slotAccepts(shape[slot], h.stock.tier));

  const order = shape
    .map((_, i) => i)
    .sort((a, b) => fits(a).length - fits(b).length || a - b);
  const used = new Set<string>();
  const picked = new Map<number, ManagerHoldingDto>();
  for (const slot of order) {
    const holding = fits(slot).find((h) => !used.has(h.stock.mint));
    if (!holding) continue;
    used.add(holding.stock.mint);
    picked.set(slot, holding);
  }

  const lineup = [...picked.entries()]
    .sort(([a], [b]) => a - b)
    .map(([slotIndex, holding]) => ({
      slotIndex,
      positionLabel: shape[slotIndex].label,
      stock: holding.stock,
      // As for any other manager: picks, not position sizes.
      balance: 0,
    }));

  const rules = captaincyRules(mode);
  const ranked = [...picked.entries()].sort(([, a], [, b]) => b.valueUsd - a.valueUsd);
  return {
    lineup,
    formation,
    captainSlot: rules.captain ? (ranked[0]?.[0] ?? null) : null,
    viceCaptainSlot: rules.vice ? (ranked[1]?.[0] ?? null) : null,
  };
}

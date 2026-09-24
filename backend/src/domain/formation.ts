import { BadRequestException } from '@nestjs/common';
import {
  DEFAULT_FORMATION,
  formationCounts,
  formationName,
  FORMATIONS,
  rosterShape,
} from './sport.js';

/** A drafted pick: which stock sits in which slot. */
export interface SlotPick {
  slot_index: number;
  token_mint: string;
}

export interface RemapResult {
  slots: SlotPick[];
  /** Mints that no longer fit the new shape (still owned, just off the team). */
  dropped: string[];
  captainSlot: number | null;
  viceCaptainSlot: number | null;
}

/** Validates a formation name sent by the app and returns it canonicalised. */
export function parseFormation(value: unknown): string {
  if (typeof value !== 'string') {
    throw new BadRequestException('formation is required, e.g. "4-4-2"');
  }
  return formationName(formationCounts(value.trim()));
}

export const formationList = (): string[] => FORMATIONS.map(formationName);

/**
 * Moves picks from one formation to another.
 *
 * Each role keeps its picks in slot order up to the new count; anything that
 * no longer fits is dropped. The armbands follow their stock if it kept a
 * place, and are cleared otherwise.
 */
export function remapFormation(input: {
  from: string | null;
  to: string;
  slots: SlotPick[];
  captainSlot: number | null;
  viceCaptainSlot: number | null;
}): RemapResult {
  const fromShape = rosterShape('football', input.from ?? DEFAULT_FORMATION);
  const toShape = rosterShape('football', input.to);

  const byRole = new Map<string, string[]>();
  for (const pick of [...input.slots].sort((a, b) => a.slot_index - b.slot_index)) {
    const role = fromShape[pick.slot_index]?.label;
    if (!role) continue;
    byRole.set(role, [...(byRole.get(role) ?? []), pick.token_mint]);
  }

  const captainMint = mintAt(input.slots, input.captainSlot);
  const viceMint = mintAt(input.slots, input.viceCaptainSlot);

  const slots: SlotPick[] = [];
  const taken = new Set<string>();
  toShape.forEach((position, slotIndex) => {
    const queue = byRole.get(position.label) ?? [];
    const mint = queue.shift();
    if (mint === undefined) return;
    slots.push({ slot_index: slotIndex, token_mint: mint });
    taken.add(mint);
  });

  const dropped = input.slots
    .map((s) => s.token_mint)
    .filter((mint) => !taken.has(mint));

  return {
    slots,
    dropped,
    captainSlot: slotOf(slots, captainMint),
    viceCaptainSlot: slotOf(slots, viceMint),
  };
}

function mintAt(slots: SlotPick[], slotIndex: number | null): string | null {
  if (slotIndex === null) return null;
  return slots.find((s) => s.slot_index === slotIndex)?.token_mint ?? null;
}

function slotOf(slots: SlotPick[], mint: string | null): number | null {
  if (mint === null) return null;
  return slots.find((s) => s.token_mint === mint)?.slot_index ?? null;
}

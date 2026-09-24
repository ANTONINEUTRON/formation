import { BadRequestException } from '@nestjs/common';
import { rosterShape } from './sport.js';
import type { SportMode } from './sport.js';

export interface CaptaincyRules {
  /** Whether the sport has a captain at all. */
  captain: boolean;
  /** Whether a vice-captain can be named (football only). */
  vice: boolean;
  /** Multiplier applied to the captain's slot score. */
  multiplier: number;
}

/**
 * Football's captain scores double with a vice-captain as backup; the
 * basketball "go-to scorer" is ×1.5; American Football has no captain
 * (docs/formation-scoring.md §5).
 */
export function captaincyRules(mode: SportMode): CaptaincyRules {
  switch (mode) {
    case 'football':
      return { captain: true, vice: true, multiplier: 2 };
    case 'basketball':
      return { captain: true, vice: false, multiplier: 1.5 };
    case 'american_football':
      return { captain: false, vice: false, multiplier: 1 };
  }
}

export interface Captaincy {
  captainSlot: number | null;
  viceCaptainSlot: number | null;
}

/** Validates a captaincy change sent by the app. */
export function parseCaptaincy(
  mode: SportMode,
  body: unknown,
  formation: string | null,
): Captaincy {
  const rules = captaincyRules(mode);
  if (!rules.captain) {
    throw new BadRequestException(`${mode} teams don't have a captain`);
  }
  const value = (body ?? {}) as Record<string, unknown>;
  const slotCount = rosterShape(mode, formation).length;

  const slot = (raw: unknown, field: string): number | null => {
    if (raw === null || raw === undefined) return null;
    if (!Number.isInteger(raw) || (raw as number) < 0 || (raw as number) >= slotCount) {
      throw new BadRequestException(`${field} must be a slot between 0 and ${slotCount - 1}`);
    }
    return raw as number;
  };

  const captainSlot = slot(value.captainSlot, 'captainSlot');
  const viceCaptainSlot = rules.vice ? slot(value.viceCaptainSlot, 'viceCaptainSlot') : null;
  if (captainSlot !== null && captainSlot === viceCaptainSlot) {
    throw new BadRequestException('The vice-captain must be a different player');
  }
  return { captainSlot, viceCaptainSlot };
}

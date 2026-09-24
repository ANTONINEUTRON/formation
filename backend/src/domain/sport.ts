import { BadRequestException } from '@nestjs/common';

export const SPORT_MODES = ['football', 'basketball', 'american_football'] as const;
export type SportMode = (typeof SPORT_MODES)[number];

export const RISK_TIERS = ['blue_chip', 'stable', 'balanced', 'growth', 'momentum'] as const;
export type RiskTier = (typeof RISK_TIERS)[number];

export interface PositionSlot {
  /** Role label, also stored on roster_slots. */
  label: string;
  /** Null means FLEX: any tier. */
  tier: RiskTier | null;
}

// ── Football: 11 starters, shape decided by the formation ────────────────────

export interface Formation {
  def: number;
  mid: number;
  fwd: number;
}

/** Every formation FPL allows: 1 GK, 3–5 DEF, 2–5 MID, 1–3 FWD. */
export const FORMATIONS: Formation[] = [
  { def: 3, mid: 4, fwd: 3 },
  { def: 3, mid: 5, fwd: 2 },
  { def: 4, mid: 3, fwd: 3 },
  { def: 4, mid: 4, fwd: 2 },
  { def: 4, mid: 5, fwd: 1 },
  { def: 5, mid: 2, fwd: 3 },
  { def: 5, mid: 3, fwd: 2 },
  { def: 5, mid: 4, fwd: 1 },
];

export const DEFAULT_FORMATION = '4-4-2';

export const FOOTBALL_ROLE_TIERS: Record<string, RiskTier> = {
  GK: 'blue_chip',
  DEF: 'stable',
  MID: 'balanced',
  FWD: 'momentum',
};

export const formationName = (f: Formation): string => `${f.def}-${f.mid}-${f.fwd}`;

export const isValidFormation = (f: Formation): boolean =>
  f.def >= 3 && f.def <= 5 && f.mid >= 2 && f.mid <= 5 && f.fwd >= 1 && f.fwd <= 3 &&
  f.def + f.mid + f.fwd === 10;

/** Slots in order: GK, defenders, midfielders, forwards. */
export function footballShape(formation: string): PositionSlot[] {
  const f = formationCounts(formation);
  return [
    { label: 'GK', tier: FOOTBALL_ROLE_TIERS.GK },
    ...Array.from({ length: f.def }, () => ({ label: 'DEF', tier: FOOTBALL_ROLE_TIERS.DEF })),
    ...Array.from({ length: f.mid }, () => ({ label: 'MID', tier: FOOTBALL_ROLE_TIERS.MID })),
    ...Array.from({ length: f.fwd }, () => ({ label: 'FWD', tier: FOOTBALL_ROLE_TIERS.FWD })),
  ];
}

export function formationCounts(formation: string): Formation {
  const [def, mid, fwd] = formation.split('-').map(Number);
  const parsed = { def, mid, fwd };
  if (!isValidFormation(parsed)) {
    throw new BadRequestException(`${formation} is not a valid formation`);
  }
  return parsed;
}

const BASKETBALL_SHAPE: PositionSlot[] = [
  { label: 'PG', tier: 'growth' },
  { label: 'SG', tier: 'growth' },
  { label: 'SF', tier: 'balanced' },
  { label: 'PF', tier: 'balanced' },
  { label: 'C', tier: 'blue_chip' },
];

const AMERICAN_FOOTBALL_SHAPE: PositionSlot[] = [
  { label: 'QB', tier: 'blue_chip' },
  { label: 'RB', tier: 'growth' },
  { label: 'RB', tier: 'balanced' },
  { label: 'WR', tier: 'momentum' },
  { label: 'WR', tier: 'growth' },
  { label: 'WR', tier: 'momentum' },
  { label: 'TE', tier: 'stable' },
  { label: 'FLEX', tier: null },
  { label: 'K', tier: 'stable' },
];

/**
 * Slot shape for a roster, in slot-index order. Slot index i here is slot
 * index i in the app (`app/lib/features/shared/domain/roster_shapes.dart`).
 */
export function rosterShape(mode: SportMode, formation?: string | null): PositionSlot[] {
  switch (mode) {
    case 'football':
      return footballShape(formation ?? DEFAULT_FORMATION);
    case 'basketball':
      return BASKETBALL_SHAPE;
    case 'american_football':
      return AMERICAN_FOOTBALL_SHAPE;
  }
}

export const DUEL_DURATION_HOURS = [1, 6, 24, 72, 168] as const;

export function parseSportMode(value: string): SportMode {
  if ((SPORT_MODES as readonly string[]).includes(value)) {
    return value as SportMode;
  }
  throw new BadRequestException(`Unknown sport mode: ${value}`);
}

export function shortAddress(address: string): string {
  return address.length <= 10
    ? address
    : `${address.slice(0, 4)}…${address.slice(-4)}`;
}

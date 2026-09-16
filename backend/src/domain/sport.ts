import { BadRequestException } from '@nestjs/common';

export const SPORT_MODES = [
  'football',
  'basketball',
  'american_football',
] as const;
export type SportMode = (typeof SPORT_MODES)[number];

export const RISK_TIERS = [
  'blue_chip',
  'stable',
  'balanced',
  'growth',
  'momentum',
] as const;
export type RiskTier = (typeof RISK_TIERS)[number];

export interface PositionSlot {
  label: string;
  /** Null means FLEX: any tier. */
  tier: RiskTier | null;
}

/**
 * Football squad roles by slot index, mirroring FPL: 2 GK, 5 DEF, 5 MID,
 * 3 FWD. Must match `footballSquadRoles` in
 * `app/lib/features/shared/domain/lineup.dart`.
 */
export const FOOTBALL_SQUAD_ROLES = [
  'GK', 'GK',
  'DEF', 'DEF', 'DEF', 'DEF', 'DEF',
  'MID', 'MID', 'MID', 'MID', 'MID',
  'FWD', 'FWD', 'FWD',
] as const;
export type FootballRole = (typeof FOOTBALL_SQUAD_ROLES)[number];

const FOOTBALL_ROLE_TIERS: Record<FootballRole, RiskTier> = {
  GK: 'blue_chip',
  DEF: 'stable',
  MID: 'balanced',
  FWD: 'momentum',
};

/**
 * Roster shapes in slot order. Must match `app/lib/features/shared/domain/
 * roster_shapes.dart`: slot index i here is slot index i in the app.
 */
export const ROSTER_SHAPES: Record<SportMode, PositionSlot[]> = {
  basketball: [
    { label: 'PG', tier: 'growth' },
    { label: 'SG', tier: 'growth' },
    { label: 'SF', tier: 'balanced' },
    { label: 'PF', tier: 'balanced' },
    { label: 'C', tier: 'blue_chip' },
  ],
  // FPL squad of 15; the starting XI is chosen by the lineup.
  football: FOOTBALL_SQUAD_ROLES.map((role) => ({
    label: role,
    tier: FOOTBALL_ROLE_TIERS[role],
  })),
  american_football: [
    { label: 'QB', tier: 'blue_chip' },
    { label: 'RB', tier: 'growth' },
    { label: 'RB', tier: 'balanced' },
    { label: 'WR', tier: 'momentum' },
    { label: 'WR', tier: 'growth' },
    { label: 'WR', tier: 'momentum' },
    { label: 'TE', tier: 'stable' },
    { label: 'FLEX', tier: null },
    { label: 'K', tier: 'stable' },
  ],
};

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

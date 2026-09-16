import { BadRequestException } from '@nestjs/common';
import { FOOTBALL_SQUAD_ROLES } from './sport.js';
import type { SportMode } from './sport.js';

/**
 * Football lineup (FPL rules): 11 starters in a valid formation, 4 ordered
 * substitutes with the backup keeper first, and captain / vice-captain on
 * starters. Mirrors `Lineup` in `app/lib/features/shared/domain/lineup.dart`.
 */
export interface Lineup {
  starters: number[];
  bench: number[];
  captain: number | null;
  viceCaptain: number | null;
}

/** Scoring metadata for one roster slot, stored on every snapshot row. */
export interface SlotMeta {
  token_mint: string;
  /** 0 = substitute, 1 = starter, 2 = captain. */
  weight: number;
  /** Squad role for like-for-like auto-subs; null outside football. */
  role: string | null;
  bench_order: number | null;
  is_vice: boolean;
}

/** 4-4-2 with the first players of each role starting. */
export function defaultLineup(mode: SportMode): Lineup | null {
  if (mode !== 'football') return null;
  return {
    starters: [0, 2, 3, 4, 5, 7, 8, 9, 10, 12, 13],
    bench: [1, 6, 11, 14],
    captain: null,
    viceCaptain: null,
  };
}

export function formationOf(starters: number[]) {
  const count = (role: string) =>
    starters.filter((s) => FOOTBALL_SQUAD_ROLES[s] === role).length;
  return { gk: count('GK'), def: count('DEF'), mid: count('MID'), fwd: count('FWD') };
}

/** Validates a lineup sent by the app. Throws a readable 400 when invalid. */
export function parseLineup(mode: SportMode, value: unknown): Lineup {
  if (mode !== 'football') {
    throw new BadRequestException('Only football has lineups');
  }
  const v = (value ?? {}) as Record<string, unknown>;
  const isSlotList = (a: unknown): a is number[] =>
    Array.isArray(a) && a.every((n) => Number.isInteger(n));
  if (!isSlotList(v.starters) || !isSlotList(v.bench)) {
    throw new BadRequestException('starters and bench must be lists of slot indexes');
  }

  const { starters, bench } = v;
  const squadSize = FOOTBALL_SQUAD_ROLES.length;
  const all = new Set([...starters, ...bench]);
  if (
    starters.length !== 11 ||
    bench.length !== 4 ||
    all.size !== squadSize ||
    [...all].some((s) => s < 0 || s >= squadSize)
  ) {
    throw new BadRequestException(
      'A lineup needs 11 starters and 4 substitutes from your 15-player squad',
    );
  }

  const f = formationOf(starters);
  if (f.gk !== 1 || f.def < 3 || f.def > 5 || f.mid < 2 || f.mid > 5 || f.fwd < 1 || f.fwd > 3) {
    throw new BadRequestException(
      `${f.def}-${f.mid}-${f.fwd} with ${f.gk} goalkeeper(s) is not a valid formation`,
    );
  }
  if (FOOTBALL_SQUAD_ROLES[bench[0]] !== 'GK') {
    throw new BadRequestException('The first substitute must be the backup goalkeeper');
  }

  const captain = v.captain ?? null;
  const viceCaptain = v.viceCaptain ?? null;
  if (captain !== null && !(Number.isInteger(captain) && starters.includes(captain as number))) {
    throw new BadRequestException('The captain must be in the starting XI');
  }
  if (
    viceCaptain !== null &&
    !(Number.isInteger(viceCaptain) && starters.includes(viceCaptain as number) && viceCaptain !== captain)
  ) {
    throw new BadRequestException('The vice-captain must be a different starter');
  }

  return {
    starters: [...starters].sort((a, b) => a - b),
    bench,
    captain: captain as number | null,
    viceCaptain: viceCaptain as number | null,
  };
}

/** Scoring metadata for a roster's filled slots under its lineup. */
export function slotMeta(
  mode: SportMode,
  slots: { slot_index: number; token_mint: string }[],
  lineup: Lineup | null,
): SlotMeta[] {
  const l = mode === 'football' ? (lineup ?? defaultLineup(mode)) : null;
  return slots.map(({ slot_index: i, token_mint }) => {
    if (!l) {
      return { token_mint, weight: 1, role: null, bench_order: null, is_vice: false };
    }
    const starter = l.starters.includes(i);
    return {
      token_mint,
      weight: l.captain === i ? 2 : starter ? 1 : 0,
      role: FOOTBALL_SQUAD_ROLES[i] ?? null,
      bench_order: starter ? null : l.bench.indexOf(i),
      is_vice: l.viceCaptain === i,
    };
  });
}

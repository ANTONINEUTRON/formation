import type { ScoreEvent, SlotContext, SportRules } from '../types.js';

// docs/formation-scoring.md §5.2
const GOAL_POINTS: Record<string, number> = { GK: 6, DEF: 6, MID: 5, FWD: 4 };
const CLEAN_SHEET_POINTS: Record<string, number> = { GK: 4, DEF: 4, MID: 1, FWD: 0 };
const GOAL_STEP = 0.03;
const CONCEDED_STEP = 0.02;
const ASSIST_ALPHA = 0.01;

export const footballRules: SportRules = {
  slotEvents(ctx: SlotContext): ScoreEvent[] {
    const events: ScoreEvent[] = [];

    const goals = Math.floor(ctx.ownReturn / GOAL_STEP);
    if (goals > 0) {
      events.push({
        code: 'goal',
        label: goals === 1 ? 'Goal' : `${goals} goals`,
        points: goals * (GOAL_POINTS[ctx.role] ?? 0),
      });
    }

    if (ctx.alpha >= ASSIST_ALPHA) {
      events.push({ code: 'assist', label: 'Assist', points: 3 });
    }

    const cleanSheet = CLEAN_SHEET_POINTS[ctx.role] ?? 0;
    if (ctx.ownReturn >= 0 && cleanSheet > 0) {
      events.push({ code: 'clean_sheet', label: 'Clean sheet', points: cleanSheet });
    }

    if (ctx.role === 'GK' || ctx.role === 'DEF') {
      const conceded = Math.floor(-ctx.ownReturn / CONCEDED_STEP);
      if (conceded > 0) {
        events.push({
          code: 'conceded',
          label: conceded === 1 ? 'Conceded' : `Conceded ${conceded}`,
          points: -conceded,
        });
      }
    }

    return events;
  },
};

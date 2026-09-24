import type { ScoreEvent, SlotContext, SportRules } from '../types.js';

// docs/formation-scoring.md §5.4
const TOUCHDOWN_STEP = 0.04;
const TURNOVER_STEP = 0.04;
const TOUCHDOWN_ROLES = ['QB', 'RB', 'WR', 'TE', 'FLEX'];
const RECEPTION_ROLES = ['WR', 'TE'];
const CLEAN_POCKET_FLOOR = 0.98;

export const americanFootballRules: SportRules = {
  slotEvents(ctx: SlotContext): ScoreEvent[] {
    const events: ScoreEvent[] = [];
    const greenSessions = ctx.sessions.filter((s) => s.change > 0).length;

    if (TOUCHDOWN_ROLES.includes(ctx.role)) {
      const touchdowns = Math.floor(ctx.ownReturn / TOUCHDOWN_STEP);
      if (touchdowns > 0) {
        events.push({
          code: 'touchdown',
          label: touchdowns === 1 ? 'Touchdown' : `${touchdowns} touchdowns`,
          points: touchdowns * 6,
        });
      }
    }

    if (RECEPTION_ROLES.includes(ctx.role) && greenSessions > 0) {
      events.push({
        code: 'reception',
        label: `${greenSessions} reception${greenSessions === 1 ? '' : 's'}`,
        points: greenSessions * 0.5,
      });
    }

    if (ctx.role !== 'K') {
      const turnovers = Math.floor(-ctx.ownReturn / TURNOVER_STEP);
      if (turnovers > 0) {
        events.push({
          code: 'turnover',
          label: turnovers === 1 ? 'Turnover' : `${turnovers} turnovers`,
          points: turnovers * -2,
        });
      }
    }

    if (ctx.role === 'QB' && ctx.lowestRelative >= CLEAN_POCKET_FLOOR) {
      events.push({ code: 'clean_pocket', label: 'Clean pocket', points: 4 });
    }

    if (ctx.role === 'K' && greenSessions > 0) {
      events.push({
        code: 'field_goal',
        label: `${greenSessions} field goal${greenSessions === 1 ? '' : 's'}`,
        points: greenSessions,
      });
    }

    return events;
  },
};

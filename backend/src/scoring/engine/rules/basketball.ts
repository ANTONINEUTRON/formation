import type { ScoreEvent, SlotContext, SportRules } from '../types.js';

// docs/formation-scoring.md §5.3
const BUCKET_STEP = 0.01;
const BUCKET_ROLES = ['PG', 'SG'];
const DOUBLE_DOUBLE_ALPHA = 0.01;

export const basketballRules: SportRules = {
  slotEvents(ctx: SlotContext): ScoreEvent[] {
    const events: ScoreEvent[] = [];

    if (BUCKET_ROLES.includes(ctx.role)) {
      const buckets = Math.floor(ctx.ownReturn / BUCKET_STEP);
      if (buckets > 0) {
        events.push({
          code: 'bucket',
          label: buckets === 1 ? 'Bucket' : `${buckets} buckets`,
          points: buckets * 2,
        });
      }
    }

    // The anchor holding up while the market falls.
    if (ctx.role === 'C') {
      const blocks = ctx.sessions.filter(
        (session, i) => session.change >= 0 && (ctx.benchmarkSessions[i]?.change ?? 0) < 0,
      ).length;
      if (blocks > 0) {
        events.push({
          code: 'block',
          label: blocks === 1 ? 'Block' : `${blocks} blocks`,
          points: blocks * 5,
        });
      }
    }

    return events;
  },

  teamEvents(contexts: SlotContext[]): ScoreEvent[] {
    const sessionCount = contexts[0]?.sessions.length ?? 0;
    let doubles = 0;
    for (let i = 0; i < sessionCount; i++) {
      const benchmark = contexts[0]?.benchmarkSessions[i]?.change ?? 0;
      const beating = contexts.filter(
        (ctx) => (ctx.sessions[i]?.change ?? 0) - benchmark >= DOUBLE_DOUBLE_ALPHA,
      ).length;
      if (beating >= 2) doubles++;
    }
    return doubles > 0
      ? [
          {
            code: 'double_double',
            label: doubles === 1 ? 'Double-double' : `${doubles} double-doubles`,
            points: doubles * 5,
          },
        ]
      : [];
  },
};

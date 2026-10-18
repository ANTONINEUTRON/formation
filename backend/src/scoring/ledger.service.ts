import { Inject, Injectable } from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { PointsLedgerTable } from '../core/db-types.js';
import { CALENDAR } from '../domain/calendar.js';
import type { GameCalendar } from '../domain/calendar.js';
import type { SportMode } from '../domain/sport.js';

export type LedgerKind = PointsLedgerTable['kind'];

/** Season recorded on points banked before season 1 kicks off. */
export const PRE_SEASON = 0;

/**
 * The one way points move: a ledger row, plus the running season total moved
 * by the same amount, in one transaction. Every kind of points (alpha, role
 * events, substitutions, bonuses, corrections) goes through here.
 *
 * Points banked before season 1 kicks off are pre-season: kept in the ledger
 * as season 0, but never added to a season total, so the season starts level.
 */
@Injectable()
export class LedgerService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(CALENDAR) private readonly calendar: GameCalendar,
  ) {}

  async award(
    userId: string,
    mode: SportMode,
    kind: LedgerKind,
    points: number,
    at: number,
    detail?: unknown,
  ): Promise<void> {
    if (points === 0) return;
    const preSeason = at < this.calendar.season(1).startsAt.getTime();
    await this.db.transaction().execute(async (trx) => {
      await trx
        .insertInto('points_ledger')
        .values({
          user_id: userId,
          sport_mode: mode,
          kind,
          points,
          detail: detail === undefined ? null : JSON.stringify(detail),
          at: new Date(at),
          season: preSeason ? PRE_SEASON : this.calendar.weekAt(at).season,
        })
        .execute();
      if (preSeason) return;
      await trx
        .insertInto('classic_scores')
        .values({ user_id: userId, sport_mode: mode, total_points: points })
        .onConflict((oc) =>
          oc.columns(['user_id', 'sport_mode']).doUpdateSet((eb) => ({
            total_points: eb(eb.ref('classic_scores.total_points'), '+', points),
            updated_at: this.clock.date(),
          })),
        )
        .execute();
    });
  }
}

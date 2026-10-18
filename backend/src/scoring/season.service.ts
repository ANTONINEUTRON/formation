import { Inject, Injectable, Logger } from '@nestjs/common';
import { sql } from 'kysely';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { CALENDAR } from '../domain/calendar.js';
import type { GameCalendar } from '../domain/calendar.js';
import { SPORT_MODES } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { TiersService } from '../xstocks/tiers.service.js';

/** Share of a season's table that earns the top-10% badge. */
const TOP_SHARE = 0.1;

export interface SeasonResultDto {
  season: number;
  mode: SportMode;
  points: number;
  rank: number;
  players: number;
}

export interface BadgeDto {
  code: string;
  label: string;
  mode: SportMode | null;
  season: number | null;
  week: number | null;
  awardedAt: string;
}

/**
 * Closes seasons (SCORING_PLAN.md §2.1). When a season's last match week ends
 * its standings are frozen into season_results, the champion and the top 10%
 * get badges, and every total restarts from what was banked since, which is
 * usually nothing. Skill, career alpha, badges and history carry over.
 */
@Injectable()
export class SeasonService {
  private readonly logger = new Logger(SeasonService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CALENDAR) private readonly calendar: GameCalendar,
    private readonly notifications: NotificationsService,
    private readonly tiers: TiersService,
  ) {}

  /** Finalises any season that has ended by [now]. Safe to call on every tick. */
  async rollover(now: number): Promise<void> {
    const current = this.calendar.seasonAt(now);
    await this.ensureSeason(current.number);
    const open = await this.db
      .selectFrom('seasons')
      .select('number')
      .where('finalized_at', 'is', null)
      .where('number', '<', current.number)
      .orderBy('number')
      .execute();
    for (const { number } of open) {
      await this.finalize(number, now);
    }
    // A new season gets fresh tiers. Failing must not hold up the rollover:
    // last season's tiers are a fine fallback.
    if (open.length > 0) {
      try {
        await this.tiers.apply(now);
      } catch (e) {
        this.logger.error(`Season tier update failed: ${String(e)}`);
      }
    }
  }

  private async ensureSeason(number: number): Promise<void> {
    // Seasons before this one may have been skipped while the server was off.
    for (let n = 1; n <= number; n++) {
      const season = this.calendar.season(n);
      await this.db
        .insertInto('seasons')
        .values({ number: n, starts_at: season.startsAt, ends_at: season.endsAt })
        .onConflict((oc) => oc.column('number').doNothing())
        .execute();
    }
  }

  async finalize(number: number, now: number): Promise<void> {
    const results: { userId: string; mode: SportMode; rank: number; players: number; points: number }[] = [];

    await this.db.transaction().execute(async (trx) => {
      const claimed = await trx
        .updateTable('seasons')
        .set({ finalized_at: new Date(now) })
        .where('number', '=', number)
        .where('finalized_at', 'is', null)
        .returning('number')
        .executeTakeFirst();
      if (!claimed) return; // Another run finalised it.

      for (const mode of SPORT_MODES) {
        const table = await trx
          .selectFrom('classic_scores')
          .innerJoin('users', 'users.id', 'classic_scores.user_id')
          .select(['classic_scores.user_id as user_id', 'classic_scores.total_points as points'])
          .where('classic_scores.sport_mode', '=', mode)
          .where('users.is_seed', '=', false)
          .orderBy('classic_scores.total_points', 'desc')
          .execute();
        if (table.length === 0) continue;

        const players = table.length;
        const topCut = Math.max(1, Math.ceil(players * TOP_SHARE));
        for (const [i, row] of table.entries()) {
          results.push({ userId: row.user_id, mode, rank: i + 1, players, points: row.points });
        }
        await trx
          .insertInto('season_results')
          .values(
            table.map((row, i) => ({
              season: number,
              user_id: row.user_id,
              sport_mode: mode,
              points: row.points,
              rank: i + 1,
              players,
            })),
          )
          .onConflict((oc) => oc.columns(['season', 'user_id', 'sport_mode']).doNothing())
          .execute();

        const badges = table.slice(0, topCut).flatMap((row, i) => [
          ...(i === 0
            ? [{ code: 'season_champion', label: `Season ${number} champion` }]
            : []),
          { code: 'season_top10', label: `Season ${number} top 10%` },
        ].map((badge) => ({
          ...badge,
          user_id: row.user_id,
          sport_mode: mode,
          season: number,
          week: null,
          awarded_at: new Date(now),
        })));
        if (badges.length > 0) {
          await trx
            .insertInto('badges')
            .values(badges)
            .onConflict((oc) => oc.doNothing())
            .execute();
        }
      }

      // A fresh table: each total restarts from what was banked since the
      // season ended (normally nothing, as this runs before the tick banks).
      await sql`
        update classic_scores c
        set total_points = coalesce((
          select sum(l.points) from points_ledger l
          where l.user_id = c.user_id and l.sport_mode = c.sport_mode and l.season > ${number}
        ), 0),
        updated_at = ${new Date(now)}
        where not exists (select 1 from users u where u.id = c.user_id and u.is_seed)
      `.execute(trx);
    });

    if (results.length === 0) return;
    await this.notifications.pushMany(
      results.map((r) => ({
        userId: r.userId,
        kind: 'season_final' as const,
        title: `Season ${number} is over`,
        body:
          r.rank === 1
            ? `You won the ${label(r.mode)} season with ${r.points} points. Season ${number + 1} starts now.`
            : `You finished #${r.rank} of ${r.players} in ${label(r.mode)}. Season ${number + 1} starts now, from zero.`,
        data: { season: number, mode: r.mode, rank: r.rank },
      })),
    );
    this.logger.log(`Season ${number} finalised (${results.length} results)`);
  }

  /** A player's finished seasons, newest first. */
  async history(userId: string): Promise<SeasonResultDto[]> {
    const rows = await this.db
      .selectFrom('season_results')
      .selectAll()
      .where('user_id', '=', userId)
      .orderBy('season', 'desc')
      .execute();
    return rows.map((r) => ({
      season: r.season,
      mode: r.sport_mode,
      points: r.points,
      rank: r.rank,
      players: r.players,
    }));
  }

  async badges(userId: string): Promise<BadgeDto[]> {
    const rows = await this.db
      .selectFrom('badges')
      .selectAll()
      .where('user_id', '=', userId)
      .orderBy('awarded_at', 'desc')
      .execute();
    return rows.map((b) => ({
      code: b.code,
      label: b.label,
      mode: b.sport_mode,
      season: b.season,
      week: b.week,
      awardedAt: new Date(b.awarded_at).toISOString(),
    }));
  }
}

const label = (mode: SportMode) => mode.replace('_', ' ');

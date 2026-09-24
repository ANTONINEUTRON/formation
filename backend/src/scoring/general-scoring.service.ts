import { Inject, Injectable, Logger } from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { GeneralEntry } from '../core/db-types.js';
import { SPORT_MODES } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import type { SessionDto } from '../domain/dto.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { EntryScoringService } from './entry-scoring.service.js';
import { FREE_SUBSTITUTIONS_PER_DAY, substitutionCost } from './engine/score-entry.js';
import type { EntryBreakdown, LineupSnapshot, SlotExits } from './engine/types.js';

const BASE_ONLY = { base: true, events: false };
const EVENTS_ONLY = { base: false, events: true };

interface Candidate {
  userId: string;
  wallet: string;
}

/**
 * The general (Classic) league, which never stops running.
 *
 * On every price tick each player's base alpha since the last tick is banked
 * straight into their running total — no gameweek has to close first. Role
 * events are different: a "goal" is a 3% move and means nothing over a
 * five-minute interval, so they are rolled up once per session (day) against
 * the lineup that started that session.
 *
 * Every movement is written to `points_ledger`, which is what lets the
 * leaderboard be filtered to any period without re-deriving history.
 */
@Injectable()
export class GeneralScoringService {
  private readonly logger = new Logger(GeneralScoringService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly scoring: EntryScoringService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Banks everything owed up to [now]. Called from the price tick. */
  async process(now = this.clock.now()): Promise<void> {
    for (const mode of SPORT_MODES) {
      for (const candidate of await this.candidates(mode)) {
        try {
          await this.bank(candidate, mode, now);
        } catch (e) {
          this.logger.warn(`Banking ${candidate.userId} (${mode}) failed: ${String(e)}`);
        }
      }
    }
  }

  /** The start of the session containing [at], aligned to the config anchor. */
  private sessionStart(at: number): number {
    const length = Math.max(1, this.config.sessionMinutes) * 60_000;
    const anchor = this.config.gameweekAnchor.getTime();
    return anchor + Math.floor((at - anchor) / length) * length;
  }

  private async bank(candidate: Candidate, mode: SportMode, now: number): Promise<void> {
    const entry = await this.entryFor(candidate, mode, now);
    // No entry means the roster isn't complete yet; it joins on a later tick.
    if (!entry) return;

    await this.bankAlpha(candidate, mode, entry, now);
    await this.rollUpEvents(candidate, mode, entry, now);
    await this.reSnapshot(candidate, mode, now);
  }

  /** Base alpha earned since the last bank, added to the running total. */
  private async bankAlpha(
    candidate: Candidate,
    mode: SportMode,
    entry: GeneralEntry,
    now: number,
  ): Promise<void> {
    const start = new Date(entry.last_banked_at).getTime();
    if (now <= start) return;

    const snapshot = parse<LineupSnapshot>(entry.snapshot);
    if (!snapshot) return;
    const { breakdown } = await this.scoring.score(
      snapshot,
      candidate.wallet,
      this.scoring.window(new Date(start), new Date(now)),
      { exits: parse<SlotExits>(entry.exits) ?? {}, parts: BASE_ONLY, at: now },
    );
    await this.award(candidate.userId, mode, 'alpha', breakdown.total, now);
    await this.db
      .updateTable('general_entries')
      .set({ last_breakdown: JSON.stringify(breakdown) })
      .where('user_id', '=', candidate.userId)
      .where('sport_mode', '=', mode)
      .execute();
  }

  /**
   * Awards role events for every session that has closed since the last
   * rollup, scoring each against the lineup that opened it.
   */
  private async rollUpEvents(
    candidate: Candidate,
    mode: SportMode,
    entry: GeneralEntry,
    now: number,
  ): Promise<void> {
    const currentSession = this.sessionStart(now);
    const lastEvents = entry.last_events_at ? new Date(entry.last_events_at).getTime() : null;

    // First sight: start the clock, award nothing for a session already underway.
    if (lastEvents === null) {
      await this.db
        .updateTable('general_entries')
        .set({ last_events_at: new Date(currentSession) })
        .where('user_id', '=', candidate.userId)
        .where('sport_mode', '=', mode)
        .execute();
      return;
    }
    if (currentSession <= lastEvents) return;

    const snapshot =
      parse<LineupSnapshot>(entry.session_snapshot) ?? parse<LineupSnapshot>(entry.snapshot);
    if (snapshot) {
      const { breakdown } = await this.scoring.score(
        snapshot,
        candidate.wallet,
        this.scoring.window(new Date(lastEvents), new Date(currentSession)),
        { parts: EVENTS_ONLY, at: currentSession },
      );
      await this.award(candidate.userId, mode, 'events', breakdown.total, now, {
        slots: breakdown.slots.filter((s) => s.events.length > 0),
        teamEvents: breakdown.teamEvents,
      });
      // Once a day, not once a tick: this is the only scoring notification.
      if (breakdown.total !== 0) {
        const sign = breakdown.total > 0 ? '+' : '';
        await this.notifications.push({
          userId: candidate.userId,
          kind: 'points',
          title: "Yesterday's points are in",
          body: `Your ${mode.replace('_', ' ')} team scored ${sign}${breakdown.total} from role events.`,
        });
      }
    }

    await this.db
      .updateTable('general_entries')
      .set({ last_events_at: new Date(currentSession) })
      .where('user_id', '=', candidate.userId)
      .where('sport_mode', '=', mode)
      .execute();
  }

  /**
   * Re-locks the current lineup as the baseline for the next interval, which
   * is what makes a substitution take effect from the next tick.
   */
  private async reSnapshot(candidate: Candidate, mode: SportMode, now: number): Promise<void> {
    const snapshot = await this.scoring.lockLineup(candidate.userId, candidate.wallet, mode);
    if (!snapshot) return;
    const openingSession = this.sessionStart(now) === now;

    await this.db
      .updateTable('general_entries')
      .set({
        snapshot: JSON.stringify(snapshot),
        exits: JSON.stringify({}),
        last_banked_at: new Date(now),
        updated_at: this.clock.date(),
        ...(openingSession ? { session_snapshot: JSON.stringify(snapshot) } : {}),
      })
      .where('user_id', '=', candidate.userId)
      .where('sport_mode', '=', mode)
      .execute();
  }

  /** Writes a ledger row and moves the running total by the same amount. */
  async award(
    userId: string,
    mode: SportMode,
    kind: 'alpha' | 'events' | 'substitution',
    points: number,
    at: number,
    detail?: unknown,
  ): Promise<void> {
    if (points === 0) return;
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
        })
        .execute();
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

  /** Loads the rolling entry, creating it the first time a roster is complete. */
  private async entryFor(
    candidate: Candidate,
    mode: SportMode,
    now: number,
  ): Promise<GeneralEntry | undefined> {
    const existing = await this.db
      .selectFrom('general_entries')
      .selectAll()
      .where('user_id', '=', candidate.userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    if (existing) return existing;

    const snapshot = await this.scoring.lockLineup(candidate.userId, candidate.wallet, mode);
    if (!snapshot) return undefined;

    await this.db
      .insertInto('general_entries')
      .values({
        user_id: candidate.userId,
        sport_mode: mode,
        snapshot: JSON.stringify(snapshot),
        session_snapshot: JSON.stringify(snapshot),
        last_banked_at: new Date(now),
        last_events_at: new Date(this.sessionStart(now)),
      })
      .onConflict((oc) => oc.columns(['user_id', 'sport_mode']).doNothing())
      .execute();
    // Nothing to bank on the tick that created the baseline.
    return undefined;
  }

  /**
   * The player's current session: points banked since it opened, plus the most
   * recent per-slot breakdown. This is what the team screen shows in place of
   * the old gameweek panel.
   */
  async sessionFor(userId: string, mode: SportMode): Promise<SessionDto | null> {
    const entry = await this.db
      .selectFrom('general_entries')
      .select(['last_breakdown', 'last_banked_at'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();

    const start = this.sessionStart(this.clock.now());
    const length = Math.max(1, this.config.sessionMinutes) * 60_000;
    const breakdown = parse<EntryBreakdown>(entry?.last_breakdown);

    return {
      startsAt: new Date(start).toISOString(),
      endsAt: new Date(start + length).toISOString(),
      entered: entry !== undefined,
      points: await this.pointsSince(userId, mode, start),
      slots: breakdown?.slots ?? [],
      teamEvents: breakdown?.teamEvents ?? [],
      substitutionsUsed: await this.substitutionsToday(userId, mode),
      freeSubstitutionsLeft: Math.max(
        0,
        FREE_SUBSTITUTIONS_PER_DAY - (await this.substitutionsToday(userId, mode)),
      ),
    };
  }

  /** Points banked by a user in a sport since [from]. */
  async pointsSince(userId: string, mode: SportMode, from: number): Promise<number> {
    const row = await this.db
      .selectFrom('points_ledger')
      .select((eb) => eb.fn.sum<string>('points').as('total'))
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .where('at', '>=', new Date(from))
      .executeTakeFirst();
    return Number(row?.total ?? 0);
  }

  /** Substitutions made today, used for the free allowance. */
  async substitutionsToday(userId: string, mode: SportMode): Promise<number> {
    const row = await this.db
      .selectFrom('daily_substitutions')
      .select('used')
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .where('day', '=', new Date(utcDay(this.clock.now())))
      .executeTakeFirst();
    return row?.used ?? 0;
  }

  /**
   * Counts a substitution and charges for it once the daily allowance is gone.
   * Returns what it cost, so the caller can tell the player.
   */
  async chargeSubstitution(userId: string, mode: SportMode): Promise<number> {
    const now = this.clock.now();
    const row = await this.db
      .insertInto('daily_substitutions')
      .values({ user_id: userId, sport_mode: mode, day: new Date(utcDay(now)), used: 1 })
      .onConflict((oc) =>
        oc.columns(['user_id', 'sport_mode', 'day']).doUpdateSet((eb) => ({
          used: eb(eb.ref('daily_substitutions.used'), '+', 1),
        })),
      )
      .returning('used')
      .executeTakeFirstOrThrow();

    const previous = substitutionCost(row.used - 1);
    const cost = substitutionCost(row.used) - previous;
    if (cost !== 0) {
      await this.award(userId, mode, 'substitution', cost, now, { used: row.used });
    }
    return cost;
  }

  private async candidates(mode: SportMode): Promise<Candidate[]> {
    const rows = await this.db
      .selectFrom('rosters')
      .innerJoin('users', 'users.id', 'rosters.user_id')
      .select(['rosters.user_id as user_id', 'users.wallet_address as wallet_address'])
      .where('rosters.sport_mode', '=', mode)
      .where('users.is_seed', '=', false)
      .execute();
    return rows.map((row) => ({ userId: row.user_id, wallet: row.wallet_address }));
  }
}

/** jsonb arrives parsed from pg, but stay tolerant of string columns. */
function parse<T>(value: unknown): T | undefined {
  if (value === null || value === undefined) return undefined;
  return typeof value === 'string' ? (JSON.parse(value) as T) : (value as T);
}

/** The UTC date of [at], which is how the substitution allowance resets. */
function utcDay(at: number): string {
  return new Date(at).toISOString().slice(0, 10);
}

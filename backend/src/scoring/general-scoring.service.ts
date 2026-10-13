import { Inject, Injectable, Logger } from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { GeneralEntry } from '../core/db-types.js';
import { CALENDAR } from '../domain/calendar.js';
import type { GameCalendar } from '../domain/calendar.js';
import { SPORT_MODES } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import type { LiveEventDto, SessionDto } from '../domain/dto.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { EntryScoringService } from './entry-scoring.service.js';
import { LedgerService } from './ledger.service.js';
import type { LedgerKind } from './ledger.service.js';
import { MatchWeekService } from './match-week.service.js';
import { round1 } from './engine/metrics.js';
import { GOAL_CODES } from './engine/skill.js';
import {
  FREE_SUBSTITUTIONS_PER_DAY,
  GENERAL_CAPS,
  substitutionCost,
} from './engine/score-entry.js';
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
    @Inject(CALENDAR) private readonly calendar: GameCalendar,
    private readonly scoring: EntryScoringService,
    private readonly notifications: NotificationsService,
    private readonly matchWeeks: MatchWeekService,
    private readonly ledger: LedgerService,
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
    const anchor = this.config.sessionAnchor.getTime();
    return anchor + Math.floor((at - anchor) / length) * length;
  }

  private async bank(candidate: Candidate, mode: SportMode, now: number): Promise<void> {
    const entry = await this.entryFor(candidate, mode, now);
    // No entry means no held stock is in the lineup yet; it joins on a later tick.
    if (!entry) return;

    const alpha = await this.bankAlpha(candidate, mode, entry, now);
    await this.rollUpEvents(candidate, mode, entry, now);
    await this.reSnapshot(candidate, mode, entry, now, alpha);
    await this.recordLiveEvents(candidate, mode, now);
  }

  /**
   * Live events (SCORING_PLAN.md §3.1): the role events today's session has
   * produced so far, recorded as provisional. They bank nothing; the daily
   * rollup confirms or disallows them. An event that falls away during the
   * day shows as disallowed until it comes back.
   */
  private async recordLiveEvents(candidate: Candidate, mode: SportMode, now: number): Promise<void> {
    const sessionStart = this.sessionStart(now);
    if (now <= sessionStart) return;
    const row = await this.db
      .selectFrom('general_entries')
      .select('session_snapshot')
      .where('user_id', '=', candidate.userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    const snapshot = parse<LineupSnapshot>(row?.session_snapshot);
    if (!snapshot) return;

    const { breakdown } = await this.scoring.score(
      snapshot,
      candidate.wallet,
      this.scoring.window(new Date(sessionStart), new Date(now)),
      { parts: EVENTS_ONLY, at: now, caps: { sessionEvents: GENERAL_CAPS.sessionEvents } },
    );
    const live = breakdown.slots.flatMap((slot) =>
      slot.events
        .filter((e) => e.code !== 'cap' && e.points !== 0)
        .map((e) => ({ slot, event: e })),
    );

    const existing = await this.db
      .selectFrom('live_events')
      .select(['mint', 'code', 'status'])
      .where('user_id', '=', candidate.userId)
      .where('sport_mode', '=', mode)
      .where('session_start', '=', new Date(sessionStart))
      .execute();
    const seen = new Set(existing.map((e) => `${e.mint}:${e.code}`));
    const firing = new Set(live.map(({ slot, event }) => `${slot.mint}:${event.code}`));

    for (const { slot, event } of live) {
      await this.db
        .insertInto('live_events')
        .values({
          user_id: candidate.userId,
          sport_mode: mode,
          session_start: new Date(sessionStart),
          slot_index: slot.slotIndex,
          mint: slot.mint,
          symbol: slot.symbol,
          code: event.code,
          label: event.label,
          points: event.points,
          at: new Date(now),
          updated_at: new Date(now),
        })
        .onConflict((oc) =>
          oc.columns(['user_id', 'sport_mode', 'session_start', 'mint', 'code']).doUpdateSet({
            label: event.label,
            points: event.points,
            status: 'provisional',
            updated_at: new Date(now),
          }),
        )
        .execute();

      // One "goal" notice per pick per day: only the first time it fires.
      if (!seen.has(`${slot.mint}:${event.code}`) && GOAL_CODES.has(event.code) && event.points > 0) {
        await this.notifications.push({
          userId: candidate.userId,
          kind: 'goal',
          title: `${event.label}! ${slot.symbol} scores`,
          body: `Provisional: it's confirmed at the end of the day if ${slot.symbol} holds its gains.`,
          data: { mode, mint: slot.mint, code: event.code },
        });
      }
    }

    const fellAway = existing.filter(
      (e) => e.status === 'provisional' && !firing.has(`${e.mint}:${e.code}`),
    );
    for (const e of fellAway) {
      await this.db
        .updateTable('live_events')
        .set({ status: 'disallowed', updated_at: new Date(now) })
        .where('user_id', '=', candidate.userId)
        .where('sport_mode', '=', mode)
        .where('session_start', '=', new Date(sessionStart))
        .where('mint', '=', e.mint)
        .where('code', '=', e.code)
        .execute();
    }
  }

  /**
   * Settles the live events of the sessions a rollup just closed: confirmed
   * if the final day's events include them, disallowed if the price fell back.
   */
  private async settleLiveEvents(
    userId: string,
    mode: SportMode,
    from: number,
    to: number,
    breakdown: EntryBreakdown | undefined,
  ): Promise<void> {
    const final = new Set(
      (breakdown?.slots ?? []).flatMap((s) =>
        s.events.filter((e) => e.points !== 0).map((e) => `${s.mint}:${e.code}`),
      ),
    );
    const rows = await this.db
      .selectFrom('live_events')
      .select(['id', 'mint', 'code'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .where('session_start', '>=', new Date(from))
      .where('session_start', '<', new Date(to))
      .where('status', '!=', 'confirmed')
      .execute();
    for (const row of rows) {
      await this.db
        .updateTable('live_events')
        .set({
          status: final.has(`${row.mint}:${row.code}`) ? 'confirmed' : 'disallowed',
          updated_at: this.clock.date(),
        })
        .where('id', '=', row.id)
        .execute();
    }
  }

  /**
   * True when [now] is the first bank of a new session. Ticks land a few
   * minutes past the hour, never exactly on a boundary, so this compares the
   * sessions of this bank and the last one rather than testing for equality.
   */
  private opensSession(entry: GeneralEntry, now: number): boolean {
    return this.sessionStart(now) > this.sessionStart(new Date(entry.last_banked_at).getTime());
  }

  /**
   * Base alpha earned since the last bank, added to the running total. Each
   * pick is capped per tick and per session (GENERAL_CAPS).
   */
  private async bankAlpha(
    candidate: Candidate,
    mode: SportMode,
    entry: GeneralEntry,
    now: number,
  ): Promise<EntryBreakdown | undefined> {
    const start = new Date(entry.last_banked_at).getTime();
    if (now <= start) return undefined;

    const snapshot = parse<LineupSnapshot>(entry.snapshot);
    if (!snapshot) return undefined;
    // The cap resets with the session; this tick counts toward the new one.
    const used = this.opensSession(entry, now)
      ? {}
      : (parse<Record<string, number>>(entry.session_base) ?? {});
    const { breakdown } = await this.scoring.score(
      snapshot,
      candidate.wallet,
      this.scoring.window(new Date(start), new Date(now)),
      {
        exits: parse<SlotExits>(entry.exits) ?? {},
        parts: BASE_ONLY,
        at: now,
        caps: {
          tickBase: GENERAL_CAPS.tickBase,
          sessionBase: GENERAL_CAPS.sessionBase,
          sessionBaseUsed: used,
        },
      },
    );
    const sessionBase = { ...used };
    for (const slot of breakdown.slots) {
      if (slot.base !== 0) sessionBase[slot.mint] = round1((sessionBase[slot.mint] ?? 0) + slot.base);
    }

    // Each pick's share and who wore the armband, so a match week can name its
    // man of the match and skill stats can take the multiplier back out.
    const bySlot = Object.fromEntries(
      breakdown.slots.flatMap((s) => (s.total !== 0 ? [[s.mint, s.total]] : [])),
    );
    const captain = breakdown.slots.find((s) => s.multiplier > 1);
    await this.award(candidate.userId, mode, 'alpha', breakdown.total, now, {
      slots: bySlot,
      captain: captain?.mint ?? null,
      multiplier: captain?.multiplier ?? 1,
    });
    await this.db
      .updateTable('general_entries')
      .set({ last_breakdown: JSON.stringify(breakdown), session_base: JSON.stringify(sessionBase) })
      .where('user_id', '=', candidate.userId)
      .where('sport_mode', '=', mode)
      .execute();
    return breakdown;
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
    let settled: EntryBreakdown | undefined;
    if (snapshot) {
      const { breakdown } = await this.scoring.score(
        snapshot,
        candidate.wallet,
        this.scoring.window(new Date(lastEvents), new Date(currentSession)),
        {
          parts: EVENTS_ONLY,
          at: currentSession,
          caps: { sessionEvents: GENERAL_CAPS.sessionEvents },
        },
      );
      settled = breakdown;
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
    await this.settleLiveEvents(candidate.userId, mode, lastEvents, currentSession, settled);

    await this.db
      .updateTable('general_entries')
      .set({ last_events_at: new Date(currentSession) })
      .where('user_id', '=', candidate.userId)
      .where('sport_mode', '=', mode)
      .execute();
  }

  /**
   * Re-locks the current lineup as the baseline for the next interval, which
   * is what makes a substitution take effect from the next tick. A pick whose
   * jump was held this tick keeps its old baseline, so the next tick can tell
   * whether the jump was real.
   */
  private async reSnapshot(
    candidate: Candidate,
    mode: SportMode,
    entry: GeneralEntry,
    now: number,
    alpha: EntryBreakdown | undefined,
  ): Promise<void> {
    const locked = await this.scoring.lockLineup(candidate.userId, candidate.wallet, mode);
    if (!locked) return;
    const snapshot = carryHeldBaselines(locked, alpha);
    const openingSession = this.opensSession(entry, now);

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
  award(
    userId: string,
    mode: SportMode,
    kind: LedgerKind,
    points: number,
    at: number,
    detail?: unknown,
  ): Promise<void> {
    return this.ledger.award(userId, mode, kind, points, at, detail);
  }

  /** Loads the rolling entry, creating it once the lineup holds at least one stock. */
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
    if (!snapshot || !this.scoring.holdsAny(snapshot)) return undefined;

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

    const now = this.clock.now();
    const start = this.sessionStart(now);
    const length = Math.max(1, this.config.sessionMinutes) * 60_000;
    const breakdown = parse<EntryBreakdown>(entry?.last_breakdown);
    const week = this.calendar.weekAt(now);

    return {
      matchWeek: {
        number: week.number,
        season: week.season,
        weekOfSeason: week.weekOfSeason,
        kickOff: week.kickOff.toISOString(),
        fullTime: week.fullTime.toISOString(),
        nextKickOff: week.nextKickOff.toISOString(),
        points: await this.pointsSince(userId, mode, week.kickOff.getTime(), week.fullTime.getTime()),
      },
      transferWindowOpen: this.calendar.inTransferWindow(now),
      liveEvents: await this.liveEvents(userId, mode, start),
      liveFixtures: await this.matchWeeks.liveFixtures(userId, mode, now),
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

  /** Today's live events for the team screen. */
  private async liveEvents(userId: string, mode: SportMode, sessionStart: number): Promise<LiveEventDto[]> {
    const rows = await this.db
      .selectFrom('live_events')
      .selectAll()
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .where('session_start', '=', new Date(sessionStart))
      .orderBy('at')
      .execute();
    return rows.map((r) => ({
      slotIndex: r.slot_index,
      mint: r.mint,
      symbol: r.symbol,
      code: r.code,
      label: r.label,
      points: r.points,
      status: r.status,
      at: new Date(r.at).toISOString(),
    }));
  }

  /** Points banked by a user in a sport since [from], up to [to] if given. */
  async pointsSince(userId: string, mode: SportMode, from: number, to?: number): Promise<number> {
    let query = this.db
      .selectFrom('points_ledger')
      .select((eb) => eb.fn.sum<string>('points').as('total'))
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .where('at', '>=', new Date(from));
    if (to !== undefined) query = query.where('at', '<=', new Date(to));
    const row = await query.executeTakeFirst();
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
    // The weekend transfer window: substitutions are free and don't count.
    if (this.calendar.inTransferWindow(now)) return 0;
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

/**
 * For each pick whose jump was held on this tick, keeps its pre-jump baseline
 * (moved with the benchmark) and the pending direction in the next snapshot,
 * instead of the fresh price.
 */
export function carryHeldBaselines(
  next: LineupSnapshot,
  breakdown: EntryBreakdown | undefined,
): LineupSnapshot {
  const held = new Map(
    (breakdown?.slots ?? []).flatMap((s) => (s.guard?.held ? [[s.mint, s.guard.state] as const] : [])),
  );
  if (held.size === 0) return next;
  return {
    ...next,
    slots: next.slots.map((slot) => {
      const state = held.get(slot.mint);
      const benchmarkNow = slot.benchmarkPrice ?? next.benchmarkPrice;
      if (!state || state.benchmark <= 0 || benchmarkNow <= 0) return slot;
      return {
        ...slot,
        startPrice: state.price * (benchmarkNow / state.benchmark),
        pending: state.pending,
      };
    }),
  };
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

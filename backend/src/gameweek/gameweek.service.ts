import { Inject, Injectable, Logger } from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { Gameweek } from '../core/db-types.js';
import type { GameweekDto } from '../domain/dto.js';
import { rosterShape, SPORT_MODES } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { EntryScoringService } from '../scoring/entry-scoring.service.js';
import { gameweekWindow } from '../scoring/engine/gameweek-window.js';
import type { GameweekConfig } from '../scoring/engine/gameweek-window.js';
import type { EntryBreakdown, LineupSnapshot } from '../scoring/engine/types.js';

/**
 * Gameweeks are the scoring windows (docs/formation-scoring.md §5.1).
 *
 * A lineup is locked when its gameweek opens, scored live on every price
 * tick, and finalised once the window ends. Roster changes made during a live
 * gameweek only take effect in the next one.
 */
@Injectable()
export class GameweekService {
  private readonly logger = new Logger(GameweekService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly scoring: EntryScoringService,
  ) {}

  private windowConfig(mode: SportMode): GameweekConfig {
    return {
      anchor: this.config.gameweekAnchor.getTime(),
      lengthMinutes: this.config.gameweekMinutes[mode],
    };
  }

  /** Closes finished gameweeks, opens the current one, scores live entries. */
  async process(now = this.clock.now()): Promise<void> {
    for (const mode of SPORT_MODES) {
      try {
        await this.closeDue(mode, now);
        const gameweek = await this.ensureCurrent(mode, now);
        await this.enterRosters(gameweek);
        await this.scoreLive(gameweek);
      } catch (e) {
        this.logger.warn(`Gameweek processing failed for ${mode}: ${String(e)}`);
      }
    }
  }

  /** The gameweek covering [now], created if it doesn't exist yet. */
  async ensureCurrent(mode: SportMode, now = this.clock.now()): Promise<Gameweek> {
    const window = gameweekWindow(now, this.windowConfig(mode));
    const startsAt = new Date(window.start);
    const existing = await this.db
      .selectFrom('gameweeks')
      .selectAll()
      .where('sport_mode', '=', mode)
      .where('starts_at', '=', startsAt)
      .executeTakeFirst();
    if (existing) return existing;

    await this.db
      .insertInto('gameweeks')
      .values({
        sport_mode: mode,
        number: window.number,
        starts_at: startsAt,
        ends_at: new Date(window.end),
      })
      .onConflict((oc) => oc.columns(['sport_mode', 'starts_at']).doNothing())
      .execute();

    return this.db
      .selectFrom('gameweeks')
      .selectAll()
      .where('sport_mode', '=', mode)
      .where('starts_at', '=', startsAt)
      .executeTakeFirstOrThrow();
  }

  /** Locks every complete roster that hasn't entered this gameweek yet. */
  async enterRosters(gameweek: Gameweek): Promise<number> {
    const candidates = await this.db
      .selectFrom('rosters')
      .innerJoin('users', 'users.id', 'rosters.user_id')
      .select(['rosters.user_id as user_id', 'users.wallet_address as wallet_address'])
      .where('rosters.sport_mode', '=', gameweek.sport_mode)
      .where('users.is_seed', '=', false)
      .execute();

    const entered = new Set(
      (
        await this.db
          .selectFrom('score_entries')
          .select('user_id')
          .where('context', '=', 'gameweek')
          .where('context_id', '=', gameweek.id)
          .execute()
      ).map((r) => r.user_id),
    );

    let locked = 0;
    for (const candidate of candidates) {
      if (entered.has(candidate.user_id)) continue;
      const snapshot = await this.scoring.lockLineup(
        candidate.user_id,
        candidate.wallet_address,
        gameweek.sport_mode,
      );
      if (!snapshot) continue; // Roster still incomplete: joins a later gameweek.
      await this.db
        .insertInto('score_entries')
        .values({
          context: 'gameweek',
          context_id: gameweek.id,
          user_id: candidate.user_id,
          sport_mode: gameweek.sport_mode,
          snapshot: JSON.stringify(snapshot),
        })
        .onConflict((oc) => oc.columns(['context', 'context_id', 'user_id']).doNothing())
        .execute();
      locked++;
    }
    return locked;
  }

  /** Rescores live entries so the app can show points moving. */
  async scoreLive(gameweek: Gameweek): Promise<void> {
    if (gameweek.status !== 'live') return;
    const window = this.scoring.window(
      new Date(gameweek.starts_at),
      new Date(Math.min(this.clock.now(), new Date(gameweek.ends_at).getTime())),
    );

    for (const entry of await this.entriesOf(gameweek.id)) {
      const { breakdown } = await this.scoring.score(entry.snapshot, entry.wallet_address, window);
      await this.db
        .updateTable('score_entries')
        .set({ live_points: breakdown.total, breakdown: JSON.stringify(breakdown), updated_at: this.clock.date() })
        .where('context', '=', 'gameweek')
        .where('context_id', '=', gameweek.id)
        .where('user_id', '=', entry.user_id)
        .execute();
    }
  }

  /** Finalises any live gameweek whose window has ended. */
  async closeDue(mode: SportMode, now = this.clock.now()): Promise<number> {
    const due = await this.db
      .selectFrom('gameweeks')
      .selectAll()
      .where('sport_mode', '=', mode)
      .where('status', '=', 'live')
      .where('ends_at', '<=', new Date(now))
      .orderBy('starts_at')
      .execute();

    for (const gameweek of due) await this.close(gameweek);
    return due.length;
  }

  /**
   * Scores every entry with final balances and adds the points to the season
   * total. Guarded on `status = 'live'`, so points are never added twice.
   */
  async close(gameweek: Gameweek): Promise<void> {
    const window = this.scoring.window(new Date(gameweek.starts_at), new Date(gameweek.ends_at));
    const entries = await this.entriesOf(gameweek.id);
    const scored: { userId: string; breakdown: EntryBreakdown; endBalances: Record<string, number> }[] =
      [];
    for (const entry of entries) {
      const result = await this.scoring.score(entry.snapshot, entry.wallet_address, window, {
        fresh: true,
      });
      scored.push({ userId: entry.user_id, ...result });
    }

    await this.db.transaction().execute(async (trx) => {
      const claimed = await trx
        .updateTable('gameweeks')
        .set({ status: 'final' })
        .where('id', '=', gameweek.id)
        .where('status', '=', 'live')
        .returning('id')
        .executeTakeFirst();
      if (!claimed) return; // Already closed by another run.

      for (const { userId, breakdown, endBalances } of scored) {
        await trx
          .updateTable('score_entries')
          .set({
            final_points: breakdown.total,
            live_points: breakdown.total,
            breakdown: JSON.stringify(breakdown),
            end_balances: JSON.stringify(endBalances),
            updated_at: this.clock.date(),
          })
          .where('context', '=', 'gameweek')
          .where('context_id', '=', gameweek.id)
          .where('user_id', '=', userId)
          .execute();

        await trx
          .insertInto('classic_scores')
          .values({
            user_id: userId,
            sport_mode: gameweek.sport_mode,
            total_points: breakdown.total,
            last_gameweek_points: breakdown.total,
            updated_at: this.clock.date(),
          })
          .onConflict((oc) =>
            oc.columns(['user_id', 'sport_mode']).doUpdateSet((eb) => ({
              total_points: eb(eb.ref('classic_scores.total_points'), '+', breakdown.total),
              last_gameweek_points: breakdown.total,
              updated_at: this.clock.date(),
            })),
          )
          .execute();
      }
    });
    this.logger.log(
      `Closed ${gameweek.sport_mode} gameweek ${gameweek.number} (${scored.length} entries)`,
    );
  }

  /** Demo control: closes the current gameweek early and opens the next. */
  async advance(mode: SportMode): Promise<Gameweek> {
    const current = await this.ensureCurrent(mode);
    await this.close(current);
    const next = await this.ensureCurrent(mode, new Date(current.ends_at).getTime());
    await this.enterRosters(next);
    return next;
  }

  async current(mode: SportMode): Promise<Gameweek | undefined> {
    return this.db
      .selectFrom('gameweeks')
      .selectAll()
      .where('sport_mode', '=', mode)
      .orderBy('starts_at', 'desc')
      .executeTakeFirst();
  }

  async history(mode: SportMode, limit = 10): Promise<Gameweek[]> {
    return this.db
      .selectFrom('gameweeks')
      .selectAll()
      .where('sport_mode', '=', mode)
      .where('status', '=', 'final')
      .orderBy('starts_at', 'desc')
      .limit(limit)
      .execute();
  }

  /** The user's entry for a gameweek, as the app's DTO. */
  async dtoFor(gameweek: Gameweek, userId: string): Promise<GameweekDto> {
    const entry = await this.db
      .selectFrom('score_entries')
      .select(['live_points', 'final_points', 'breakdown'])
      .where('context', '=', 'gameweek')
      .where('context_id', '=', gameweek.id)
      .where('user_id', '=', userId)
      .executeTakeFirst();
    const breakdown = parseJson<EntryBreakdown>(entry?.breakdown);

    return {
      id: gameweek.id,
      number: gameweek.number,
      startsAt: new Date(gameweek.starts_at).toISOString(),
      endsAt: new Date(gameweek.ends_at).toISOString(),
      status: gameweek.status,
      entered: entry !== undefined,
      points: entry?.final_points ?? entry?.live_points ?? 0,
      slots: breakdown?.slots ?? [],
      teamEvents: breakdown?.teamEvents ?? [],
    };
  }

  /** The lineup locked into the current gameweek, for change detection. */
  async lockedSnapshot(gameweekId: string, userId: string): Promise<LineupSnapshot | null> {
    const row = await this.db
      .selectFrom('score_entries')
      .select('snapshot')
      .where('context', '=', 'gameweek')
      .where('context_id', '=', gameweekId)
      .where('user_id', '=', userId)
      .executeTakeFirst();
    return parseJson<LineupSnapshot>(row?.snapshot) ?? null;
  }

  /** Live points per user in a gameweek, for the leaderboard. */
  async livePointsByUser(gameweekId: string): Promise<Map<string, number>> {
    const rows = await this.db
      .selectFrom('score_entries')
      .select(['user_id', 'live_points', 'final_points'])
      .where('context', '=', 'gameweek')
      .where('context_id', '=', gameweekId)
      .execute();
    return new Map(rows.map((r) => [r.user_id, r.final_points ?? r.live_points]));
  }

  /** True when the roster no longer matches the lineup locked for scoring. */
  async hasPendingChanges(
    gameweekId: string,
    userId: string,
    wallet: string,
    mode: SportMode,
  ): Promise<boolean> {
    const locked = await this.lockedSnapshot(gameweekId, userId);
    if (!locked) return false;
    const roster = await this.db
      .selectFrom('rosters')
      .select(['id', 'formation', 'captain_slot', 'vice_captain_slot'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    if (!roster) return false;
    if (
      roster.formation !== locked.formation ||
      roster.captain_slot !== locked.captainSlot ||
      roster.vice_captain_slot !== locked.viceCaptainSlot
    ) {
      return true;
    }
    const slots = await this.db
      .selectFrom('roster_slots')
      .select(['slot_index', 'token_mint'])
      .where('roster_id', '=', roster.id)
      .orderBy('slot_index')
      .execute();
    if (slots.length !== rosterShape(mode, roster.formation).length) return true;
    return slots.some(
      (slot) =>
        locked.slots.find((s) => s.slotIndex === slot.slot_index)?.mint !== slot.token_mint,
    );
  }

  private async entriesOf(gameweekId: string) {
    const rows = await this.db
      .selectFrom('score_entries')
      .innerJoin('users', 'users.id', 'score_entries.user_id')
      .select([
        'score_entries.user_id as user_id',
        'score_entries.snapshot as snapshot',
        'users.wallet_address as wallet_address',
      ])
      .where('score_entries.context', '=', 'gameweek')
      .where('score_entries.context_id', '=', gameweekId)
      .execute();
    return rows.map((row) => ({
      user_id: row.user_id,
      wallet_address: row.wallet_address,
      snapshot: parseJson<LineupSnapshot>(row.snapshot)!,
    }));
  }
}

/** jsonb comes back parsed from pg, but stays tolerant of string columns. */
export function parseJson<T>(value: unknown): T | undefined {
  if (value === null || value === undefined) return undefined;
  return typeof value === 'string' ? (JSON.parse(value) as T) : (value as T);
}

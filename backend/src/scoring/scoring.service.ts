import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ChainService } from '../core/chain.service.js';
import { DbService, unwrap } from '../core/db.service.js';
import { slotMeta } from '../domain/lineup.js';
import type { Lineup, SlotMeta } from '../domain/lineup.js';
import type { SportMode } from '../domain/sport.js';
import { scoreSnapshots } from './score-window.js';
import type { SnapshotRow } from './score-window.js';

/** Columns to select when reading snapshots back for scoring. */
export const SNAPSHOT_COLUMNS =
  'token_mint, balance, price_usd, weight, role, bench_order, is_vice';

interface TickRosterRow {
  id: string;
  user_id: string;
  sport_mode: SportMode;
  last_tick_at: string | null;
  lineup: Lineup | null;
  users: { wallet_address: string; is_seed: boolean };
  roster_slots: { slot_index: number; token_mint: string }[];
}

/** Lineup metadata carried from a stored snapshot row. */
export function metaOf(row: SnapshotRow): SlotMeta {
  return {
    token_mint: row.token_mint,
    weight: row.weight ?? 1,
    role: row.role ?? null,
    bench_order: row.bench_order ?? null,
    is_vice: row.is_vice ?? false,
  };
}

/** Snapshots and the hourly Classic scoring tick (spec §3.5, §4.3). */
@Injectable()
export class ScoringService {
  private readonly logger = new Logger(ScoringService.name);

  constructor(
    private readonly db: DbService,
    private readonly chain: ChainService,
  ) {}

  /** Real balances and prices for [slots] in [wallet] right now. */
  async snapshotSlots(
    wallet: string,
    slots: SlotMeta[],
    { fresh = false } = {},
  ): Promise<SnapshotRow[]> {
    if (slots.length === 0) return [];
    const [balances, prices] = await Promise.all([
      this.chain.getBalances(wallet, { fresh }),
      this.chain.getPrices(
        slots.map((s) => s.token_mint),
        { fresh },
      ),
    ]);
    return slots.flatMap((slot) => {
      const price = prices.get(slot.token_mint);
      return price
        ? [{ ...slot, balance: balances.get(slot.token_mint) ?? 0, price_usd: price.usdPrice }]
        : [];
    });
  }

  /** Snapshot of a user's current roster and lineup in [mode]. */
  async snapshotRoster(
    userId: string,
    wallet: string,
    mode: SportMode,
  ): Promise<SnapshotRow[]> {
    const roster = unwrap(
      await this.db.supabase
        .from('rosters')
        .select('lineup, roster_slots(slot_index, token_mint)')
        .eq('user_id', userId)
        .eq('sport_mode', mode)
        .maybeSingle(),
    ) as unknown as Pick<TickRosterRow, 'lineup' | 'roster_slots'> | null;
    return this.snapshotSlots(
      wallet,
      slotMeta(mode, roster?.roster_slots ?? [], roster?.lineup ?? null),
      { fresh: true },
    );
  }

  @Cron(CronExpression.EVERY_HOUR)
  async hourlyTick() {
    try {
      const result = await this.runTick();
      this.logger.log(`Tick scored ${result.rostersScored} rosters`);
    } catch (e) {
      this.logger.error(`Tick failed: ${String(e)}`);
    }
  }

  /**
   * Scores every real roster against its previous tick's snapshot, then
   * stores the current snapshot (with lineup weights) as the next baseline.
   * A roster's first tick only records the baseline.
   */
  async runTick(): Promise<{ rostersScored: number; tickAt: string }> {
    const tickAt = new Date().toISOString();
    const rosters = unwrap(
      await this.db.supabase
        .from('rosters')
        .select(
          'id, user_id, sport_mode, last_tick_at, lineup, users!inner(wallet_address, is_seed), roster_slots(slot_index, token_mint)',
        ),
    ) as unknown as TickRosterRow[];
    this.chain.invalidateBalances();

    let rostersScored = 0;
    for (const roster of rosters) {
      if (roster.roster_slots.length === 0 || roster.users.is_seed) continue;
      try {
        await this.tickRoster(roster, tickAt);
        rostersScored++;
      } catch (e) {
        this.logger.warn(`Roster ${roster.id} skipped: ${String(e)}`);
      }
    }
    return { rostersScored, tickAt };
  }

  private async tickRoster(roster: TickRosterRow, tickAt: string) {
    const db = this.db.supabase;
    const current = await this.snapshotSlots(
      roster.users.wallet_address,
      slotMeta(roster.sport_mode, roster.roster_slots, roster.lineup),
    );
    const previous: SnapshotRow[] = roster.last_tick_at
      ? unwrap(
          await db
            .from('hourly_snapshots')
            .select(SNAPSHOT_COLUMNS)
            .eq('roster_id', roster.id)
            .eq('captured_at', roster.last_tick_at),
        )
      : [];
    const score = scoreSnapshots(previous, current);

    if (current.length > 0) {
      unwrap(
        await db
          .from('hourly_snapshots')
          .insert(current.map((r) => ({ ...r, roster_id: roster.id, captured_at: tickAt }))),
      );
    }

    const existing: { total_points: number } | null = unwrap(
      await db
        .from('classic_scores')
        .select('total_points')
        .eq('user_id', roster.user_id)
        .eq('sport_mode', roster.sport_mode)
        .maybeSingle(),
    );
    unwrap(
      await db.from('classic_scores').upsert({
        user_id: roster.user_id,
        sport_mode: roster.sport_mode,
        total_points: Number(existing?.total_points ?? 0) + score.points,
        updated_at: tickAt,
      }),
    );
    unwrap(
      await db
        .from('rosters')
        .update({ last_return_pct: score.returnPct, last_tick_at: tickAt })
        .eq('id', roster.id),
    );
  }
}

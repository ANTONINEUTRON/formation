import { Inject, Injectable, Logger } from '@nestjs/common';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { CALENDAR } from '../domain/calendar.js';
import type { GameCalendar, MatchWeek } from '../domain/calendar.js';
import type { PortfolioHealthDto } from '../domain/dto.js';
import { sectorLabel, sectorOf } from '../domain/sectors.js';
import type { Sector } from '../domain/sectors.js';
import { RISK_TIERS } from '../domain/sport.js';
import type { RiskTier, SportMode } from '../domain/sport.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { round1 } from './engine/metrics.js';
import type { LineupSnapshot, SlotScore } from './engine/types.js';
import { LedgerService } from './ledger.service.js';

/** Share of a team in one sector past which the health card warns about it. */
const CONCENTRATION_WARNING = 0.5;

/**
 * The portfolio-building layer (SCORING_PLAN.md Phase 5). Tiers already make
 * every team diversified by design; this makes balance pay a little and
 * explains, in football terms, what balance did for the team each week.
 */
@Injectable()
export class PortfolioService {
  private readonly logger = new Logger(PortfolioService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CALENDAR) private readonly calendar: GameCalendar,
    private readonly xstocks: XStocksService,
    private readonly ledger: LedgerService,
  ) {}

  /**
   * At full time: +[teamBalanceBonus] for every team whose held lineup spans
   * [teamBalanceSectors] or more sectors. Banked at full time itself, so it
   * counts toward the week it was earned in.
   */
  async awardBalanceBonus(week: MatchWeek): Promise<number> {
    const bonus = this.config.teamBalanceBonus;
    if (bonus <= 0) return 0;
    const entries = await this.db
      .selectFrom('general_entries')
      .innerJoin('users', 'users.id', 'general_entries.user_id')
      .select(['general_entries.user_id as user_id', 'general_entries.sport_mode as mode', 'general_entries.snapshot as snapshot'])
      .where('users.is_seed', '=', false)
      .execute();
    const stocks = await this.xstocks.byMint();

    let awarded = 0;
    for (const entry of entries) {
      const snapshot = parse<LineupSnapshot>(entry.snapshot);
      const sectors = new Set<Sector>();
      for (const slot of snapshot?.slots ?? []) {
        if (slot.startBalance <= 0 || slot.startPrice <= 0) continue;
        const row = stocks.get(slot.mint);
        const sector = sectorOf(slot.symbol, row?.sector);
        if (sector) sectors.add(sector);
      }
      if (sectors.size < this.config.teamBalanceSectors) continue;
      await this.ledger.award(entry.user_id, entry.mode, 'bonus', bonus, week.fullTime.getTime(), {
        code: 'balance',
        label: 'Balanced team',
        week: week.number,
        sectors: [...sectors],
      });
      awarded++;
    }
    if (awarded > 0) this.logger.log(`Balance bonus for ${awarded} teams in match week ${week.number}`);
    return awarded;
  }

  /**
   * The weekly portfolio health card: tier balance, sector concentration,
   * who carried and who dragged the team, and what that teaches.
   */
  async health(userId: string, mode: SportMode, now: number): Promise<PortfolioHealthDto> {
    const week = this.calendar.weekAt(now);
    const [entry, stocks, rows] = await Promise.all([
      this.db
        .selectFrom('general_entries')
        .select('snapshot')
        .where('user_id', '=', userId)
        .where('sport_mode', '=', mode)
        .executeTakeFirst(),
      this.xstocks.byMint(),
      this.db
        .selectFrom('points_ledger')
        .select(['kind', 'points', 'detail'])
        .where('user_id', '=', userId)
        .where('sport_mode', '=', mode)
        .where('at', '>=', week.kickOff)
        .where('at', '<=', week.fullTime)
        .execute(),
    ]);
    const snapshot = parse<LineupSnapshot>(entry?.snapshot);
    const held = (snapshot?.slots ?? []).filter((s) => s.startBalance > 0 && s.startPrice > 0);

    // Value in each sector and tier.
    const total = held.reduce((sum, s) => sum + s.startBalance * s.startPrice, 0);
    const bySector = new Map<Sector | null, number>();
    const tiers = new Map<RiskTier, number>();
    const tierOf = new Map<string, RiskTier>();
    for (const slot of held) {
      const row = stocks.get(slot.mint);
      const sector = sectorOf(slot.symbol, row?.sector);
      bySector.set(sector, (bySector.get(sector) ?? 0) + slot.startBalance * slot.startPrice);
      if (row) {
        tiers.set(row.tier, (tiers.get(row.tier) ?? 0) + 1);
        tierOf.set(slot.mint, row.tier);
      }
    }
    const sectors = [...bySector.entries()]
      .filter((e): e is [Sector, number] => e[0] !== null)
      .map(([sector, value]) => ({
        sector,
        label: sectorLabel(sector),
        sharePct: total > 0 ? Math.round((value / total) * 100) : 0,
      }))
      .sort((a, b) => b.sharePct - a.sharePct);

    // This week's points by pick, from the ledger.
    const byPick = new Map<string, number>();
    let weekPoints = 0;
    let bonusEarned = false;
    for (const row of rows) {
      weekPoints += row.points;
      if (row.kind === 'bonus') bonusEarned = true;
      if (row.kind === 'alpha') {
        const detail = (row.detail ?? {}) as { slots?: Record<string, number> };
        for (const [mint, p] of Object.entries(detail.slots ?? {})) byPick.set(mint, (byPick.get(mint) ?? 0) + p);
      } else if (row.kind === 'events') {
        const detail = (row.detail ?? {}) as { slots?: SlotScore[] };
        for (const s of detail.slots ?? []) byPick.set(s.mint, (byPick.get(s.mint) ?? 0) + s.total);
      }
    }
    const symbol = (mint: string) => stocks.get(mint)?.symbol ?? mint;
    const ranked = [...byPick.entries()].sort((a, b) => b[1] - a[1]);
    const best = ranked[0];
    const worst = ranked.at(-1);
    const carried = best && best[1] > 0 ? { symbol: symbol(best[0]), points: round1(best[1]) } : null;
    const dragged = worst && worst[1] < 0 ? { symbol: symbol(worst[0]), points: round1(worst[1]) } : null;

    const needed = this.config.teamBalanceSectors;
    const lessons: string[] = [];
    const top = sectors[0];
    if (top && top.sharePct / 100 >= CONCENTRATION_WARNING) {
      lessons.push(
        `${top.sharePct}% of your team is in ${top.label.toLowerCase()}. When ${top.label.toLowerCase()} has a bad day, so do you.`,
      );
    }
    if (sectors.length >= needed) {
      lessons.push(
        `You span ${sectors.length} sectors: that's balance, and it's worth +${this.config.teamBalanceBonus} at full time.`,
      );
    } else if (this.config.teamBalanceBonus > 0) {
      const short = needed - sectors.length;
      lessons.push(
        `${short} more sector${short === 1 ? '' : 's'} and your team earns the +${this.config.teamBalanceBonus} balance bonus at full time.`,
      );
    }
    const steady = [...byPick.entries()]
      .filter(([mint]) => tierOf.get(mint) === 'blue_chip')
      .reduce((sum, [, p]) => sum + p, 0);
    if (weekPoints < 0 && steady >= 0 && byPick.size > 0) {
      lessons.push('Your blue chips held while the rest fell: that is what they are for.');
    }
    if (carried && dragged) {
      lessons.push(
        `${carried.symbol} carried the team (${signed(carried.points)}) while ${dragged.symbol} dragged it (${signed(dragged.points)}).`,
      );
    } else if (carried) {
      lessons.push(`${carried.symbol} carried the team this week (${signed(carried.points)}).`);
    }
    if (lessons.length === 0) lessons.push('Nothing banked yet this week. Balance shows once the market moves.');

    return {
      mode,
      week: week.number,
      weekOfSeason: week.weekOfSeason,
      season: week.season,
      points: round1(weekPoints),
      tiers: RISK_TIERS.filter((t) => tiers.has(t)).map((tier) => ({ tier, count: tiers.get(tier)! })),
      sectors,
      balance: {
        sectors: sectors.length,
        needed,
        bonus: this.config.teamBalanceBonus,
        earned: bonusEarned,
      },
      carried,
      dragged,
      lessons,
    };
  }
}

function parse<T>(value: unknown): T | undefined {
  if (value === null || value === undefined) return undefined;
  return typeof value === 'string' ? (JSON.parse(value) as T) : (value as T);
}

const signed = (n: number) => `${n > 0 ? '+' : ''}${n}`;

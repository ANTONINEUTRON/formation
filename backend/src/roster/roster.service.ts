import { BadRequestException, Injectable } from '@nestjs/common';
import { ChainService } from '../core/chain.service.js';
import { DbService, unwrap } from '../core/db.service.js';
import { AuthUser, RosterDto } from '../domain/dto.js';
import { defaultLineup, parseLineup } from '../domain/lineup.js';
import type { Lineup } from '../domain/lineup.js';
import { ROSTER_SHAPES, SportMode } from '../domain/sport.js';
import { LeagueService } from '../league/league.service.js';
import { XStocksService } from '../xstocks/xstocks.service.js';

interface RosterRow {
  id: string;
  lineup: Lineup | null;
  last_return_pct: number;
  last_tick_at: string | null;
  roster_slots: { slot_index: number; token_mint: string }[];
}

@Injectable()
export class RosterService {
  constructor(
    private readonly db: DbService,
    private readonly chain: ChainService,
    private readonly xstocks: XStocksService,
    private readonly league: LeagueService,
  ) {}

  async getRoster(user: AuthUser, mode: SportMode): Promise<RosterDto> {
    const roster = await this.find(user.id, mode);
    const slots = roster?.roster_slots ?? [];
    const mints = slots.map((s) => s.token_mint);
    const [stocks, prices, balances, standing] = await Promise.all([
      this.xstocks.byMint(),
      this.chain.getPrices(mints),
      mints.length > 0
        ? this.chain.getBalances(user.walletAddress)
        : Promise.resolve(new Map<string, number>()),
      this.league.standing(user.id, mode),
    ]);
    const bySlot = new Map(slots.map((s) => [s.slot_index, s]));

    return {
      mode,
      slots: ROSTER_SHAPES[mode].map((position, slotIndex) => {
        const slot = bySlot.get(slotIndex);
        const row = slot ? stocks.get(slot.token_mint) : undefined;
        return {
          slotIndex,
          positionLabel: position.label,
          stock: row ? this.xstocks.toDto(row, prices.get(row.mint)) : null,
          balance: slot ? (balances.get(slot.token_mint) ?? 0) : 0,
        };
      }),
      lastReturnPct: roster?.last_return_pct ?? 0,
      classicPoints: standing?.points ?? 0,
      classicRank: mints.length > 0 ? (standing?.rank ?? null) : null,
      lastTickAt: roster?.last_tick_at ?? null,
      lineup: mode === 'football' ? (roster?.lineup ?? defaultLineup(mode)) : null,
    };
  }

  /** Football only: saves formation, bench order and armbands. */
  async setLineup(user: AuthUser, mode: SportMode, value: unknown): Promise<RosterDto> {
    const lineup = parseLineup(mode, value);
    const roster = await this.ensure(user.id, mode);
    unwrap(
      await this.db.supabase.from('rosters').update({ lineup }).eq('id', roster.id),
    );
    return this.getRoster(user, mode);
  }

  /** Puts a held xStock into a slot after checking tier and real balance. */
  async fillSlot(
    user: AuthUser,
    mode: SportMode,
    slotIndex: number,
    mint: string,
  ): Promise<RosterDto> {
    const position = ROSTER_SHAPES[mode][slotIndex];
    if (!position) throw new BadRequestException('Invalid slot');

    const stock = (await this.xstocks.byMint()).get(mint);
    if (!stock) throw new BadRequestException('Unsupported token');
    if (position.tier && position.tier !== stock.tier) {
      throw new BadRequestException(
        `${stock.symbol} can't play ${position.label}: it needs a ${position.tier} stock`,
      );
    }

    const balances = await this.chain.getBalances(user.walletAddress, {
      fresh: true,
    });
    if ((balances.get(mint) ?? 0) <= 0) {
      throw new BadRequestException(`You do not hold ${stock.symbol}`);
    }

    const roster = await this.ensure(user.id, mode);
    if (
      roster.roster_slots.some(
        (s) => s.token_mint === mint && s.slot_index !== slotIndex,
      )
    ) {
      throw new BadRequestException(`${stock.symbol} is already on this team`);
    }

    unwrap(
      await this.db.supabase.from('roster_slots').upsert({
        roster_id: roster.id,
        slot_index: slotIndex,
        position_label: position.label,
        token_mint: mint,
      }),
    );
    return this.getRoster(user, mode);
  }

  /** True when every slot in the user's roster for [mode] is filled. */
  async isComplete(userId: string, mode: SportMode): Promise<boolean> {
    const roster = await this.find(userId, mode);
    return (roster?.roster_slots.length ?? 0) === ROSTER_SHAPES[mode].length;
  }

  private async find(userId: string, mode: SportMode): Promise<RosterRow | null> {
    return unwrap(
      await this.db.supabase
        .from('rosters')
        .select('id, lineup, last_return_pct, last_tick_at, roster_slots(slot_index, token_mint)')
        .eq('user_id', userId)
        .eq('sport_mode', mode)
        .maybeSingle(),
    );
  }

  /** Creates the roster and the user's league entry on first draft. */
  private async ensure(userId: string, mode: SportMode): Promise<RosterRow> {
    const existing = await this.find(userId, mode);
    if (existing) return existing;
    const db = this.db.supabase;
    unwrap(
      await db
        .from('rosters')
        .insert({ user_id: userId, sport_mode: mode, lineup: defaultLineup(mode) }),
    );
    unwrap(
      await db
        .from('classic_scores')
        .upsert({ user_id: userId, sport_mode: mode }, { ignoreDuplicates: true }),
    );
    return (await this.find(userId, mode))!;
  }
}

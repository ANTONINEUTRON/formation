import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { BALANCE_SOURCE, PRICE_SOURCE } from '../core/sources.js';
import type { BalanceSource, PriceSource } from '../core/sources.js';
import { parseCaptaincy } from '../domain/captaincy.js';
import type { AuthUser, FormationChangeDto, RosterDto } from '../domain/dto.js';
import { parseFormation, remapFormation } from '../domain/formation.js';
import { DEFAULT_FORMATION, rosterShape } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { LeagueService } from '../league/league.service.js';
import { ManagersService } from '../managers/managers.service.js';
import { GeneralScoringService } from '../scoring/general-scoring.service.js';
import { XStocksService } from '../xstocks/xstocks.service.js';

interface RosterRow {
  id: string;
  formation: string | null;
  captain_slot: number | null;
  vice_captain_slot: number | null;
}

@Injectable()
export class RosterService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(BALANCE_SOURCE) private readonly balances: BalanceSource,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
    private readonly xstocks: XStocksService,
    private readonly league: LeagueService,
    private readonly general: GeneralScoringService,
    private readonly managers: ManagersService,
  ) {}

  async getRoster(user: AuthUser, mode: SportMode): Promise<RosterDto> {
    const roster = await this.find(user.id, mode);
    const formation = mode === 'football' ? (roster?.formation ?? DEFAULT_FORMATION) : null;
    const shape = rosterShape(mode, formation);
    const slots = roster ? await this.slotsOf(roster.id) : [];
    const mints = slots.map((s) => s.token_mint);

    // The wallet is the squad: everything held is available, and whatever
    // isn't in the starting lineup sits on the bench.
    const [stocks, balances, standing, session] = await Promise.all([
      this.xstocks.byMint(),
      this.balances.getBalances(user.walletAddress),
      this.league.standing(user.id, mode),
      this.general.sessionFor(user.id, mode),
    ]);
    const held = [...balances].filter(([mint, amount]) => stocks.has(mint) && amount > 0);
    const priced = await this.prices.getPrices(held.map(([mint]) => mint));
    const bySlot = new Map(slots.map((s) => [s.slot_index, s]));
    const started = new Set(mints);

    return {
      mode,
      formation,
      captainSlot: roster?.captain_slot ?? null,
      viceCaptainSlot: roster?.vice_captain_slot ?? null,
      slots: shape.map((position, slotIndex) => {
        const slot = bySlot.get(slotIndex);
        const row = slot ? stocks.get(slot.token_mint) : undefined;
        return {
          slotIndex,
          positionLabel: position.label,
          stock: row ? this.xstocks.toDto(row, priced.get(row.mint)) : null,
          balance: slot ? (balances.get(slot.token_mint) ?? 0) : 0,
        };
      }),
      classicPoints: standing?.points ?? 0,
      classicRank: mints.length > 0 ? (standing?.rank ?? null) : null,
      session,
      bench: held
        .filter(([mint]) => !started.has(mint))
        .flatMap(([mint, balance]) => {
          const row = stocks.get(mint);
          if (!row) return [];
          return [
            {
              stock: this.xstocks.toDto(row, priced.get(mint)),
              balance,
              eligibleSlots: shape.flatMap((position, i) =>
                !position.tier || position.tier === row.tier ? [i] : [],
              ),
            },
          ];
        }),
    };
  }

  /** Puts a held xStock into a slot after checking tier and real balance. */
  async fillSlot(
    user: AuthUser,
    mode: SportMode,
    slotIndex: number,
    mint: string,
  ): Promise<RosterDto> {
    const roster = await this.ensure(user.id, mode);
    const shape = rosterShape(mode, roster.formation);
    const position = shape[slotIndex];
    if (!position) throw new BadRequestException('Invalid slot');

    const stock = (await this.xstocks.byMint()).get(mint);
    if (!stock) throw new BadRequestException('Unsupported token');
    if (position.tier && position.tier !== stock.tier) {
      throw new BadRequestException(
        `${stock.symbol} can't play ${position.label}: it needs a ${position.tier} stock`,
      );
    }

    const balances = await this.balances.getBalances(user.walletAddress, { fresh: true });
    if ((balances.get(mint) ?? 0) <= 0) {
      throw new BadRequestException(`You do not hold ${stock.symbol}`);
    }

    const slots = await this.slotsOf(roster.id);
    if (slots.some((s) => s.token_mint === mint && s.slot_index !== slotIndex)) {
      throw new BadRequestException(`${stock.symbol} is already on this team`);
    }

    // Bringing a bench stock into an occupied slot is a substitution; filling
    // an empty slot during the initial draft is not. Buying and selling — the
    // transfers — happen through the swap flow and are never charged.
    const previous = slots.find((s) => s.slot_index === slotIndex);
    const isSubstitution = previous !== undefined && previous.token_mint !== mint;

    await this.db
      .insertInto('roster_slots')
      .values({
        roster_id: roster.id,
        slot_index: slotIndex,
        position_label: position.label,
        token_mint: mint,
      })
      .onConflict((oc) =>
        oc.columns(['roster_id', 'slot_index']).doUpdateSet({
          token_mint: mint,
          position_label: position.label,
        }),
      )
      .execute();

    if (isSubstitution) {
      await this.general.chargeSubstitution(user.id, mode);
      const stocks = await this.xstocks.byMint();
      await this.managers.announceMove(user.id, mode, {
        off: stocks.get(previous.token_mint)?.symbol ?? 'a pick',
        on: stock.symbol,
      });
    }
    return this.getRoster(user, mode);
  }

  /**
   * Football only: switches formation, keeping each role's picks in order.
   * Anything that no longer fits comes off the team (the stock is still owned).
   * Takes effect from the next tick; any running league keeps its locked lineup.
   */
  async setFormation(
    user: AuthUser,
    mode: SportMode,
    value: unknown,
  ): Promise<FormationChangeDto> {
    if (mode !== 'football') {
      throw new BadRequestException('Only football teams have formations');
    }
    const formation = parseFormation(value);
    const roster = await this.ensure(user.id, mode);
    const slots = await this.slotsOf(roster.id);

    const result = remapFormation({
      from: roster.formation,
      to: formation,
      slots,
      captainSlot: roster.captain_slot,
      viceCaptainSlot: roster.vice_captain_slot,
    });
    const shape = rosterShape(mode, formation);

    await this.db.transaction().execute(async (trx) => {
      await trx
        .updateTable('rosters')
        .set({
          formation,
          captain_slot: result.captainSlot,
          vice_captain_slot: result.viceCaptainSlot,
        })
        .where('id', '=', roster.id)
        .execute();
      await trx.deleteFrom('roster_slots').where('roster_id', '=', roster.id).execute();
      if (result.slots.length > 0) {
        await trx
          .insertInto('roster_slots')
          .values(
            result.slots.map((slot) => ({
              roster_id: roster.id,
              slot_index: slot.slot_index,
              position_label: shape[slot.slot_index].label,
              token_mint: slot.token_mint,
            })),
          )
          .execute();
      }
    });

    const stocks = await this.xstocks.byMint();
    const prices = await this.prices.getPrices(result.dropped);
    return {
      roster: await this.getRoster(user, mode),
      dropped: result.dropped.flatMap((mint) => {
        const row = stocks.get(mint);
        return row ? [this.xstocks.toDto(row, prices.get(mint))] : [];
      }),
    };
  }

  /** Sets the captain (and football's vice-captain). */
  async setCaptaincy(user: AuthUser, mode: SportMode, body: unknown): Promise<RosterDto> {
    const roster = await this.ensure(user.id, mode);
    const { captainSlot, viceCaptainSlot } = parseCaptaincy(mode, body, roster.formation);
    const slots = await this.slotsOf(roster.id);
    const filled = new Set(slots.map((s) => s.slot_index));

    for (const [slot, field] of [
      [captainSlot, 'captain'],
      [viceCaptainSlot, 'vice-captain'],
    ] as const) {
      if (slot !== null && !filled.has(slot)) {
        throw new BadRequestException(`Pick a stock for that slot before making it ${field}`);
      }
    }

    await this.db
      .updateTable('rosters')
      .set({ captain_slot: captainSlot, vice_captain_slot: viceCaptainSlot })
      .where('id', '=', roster.id)
      .execute();
    return this.getRoster(user, mode);
  }

  /** True when every slot in the user's roster for [mode] is filled. */
  async isComplete(userId: string, mode: SportMode): Promise<boolean> {
    const roster = await this.find(userId, mode);
    if (!roster) return false;
    const slots = await this.slotsOf(roster.id);
    return slots.length === rosterShape(mode, roster.formation).length;
  }

  private async find(userId: string, mode: SportMode): Promise<RosterRow | undefined> {
    return this.db
      .selectFrom('rosters')
      .select(['id', 'formation', 'captain_slot', 'vice_captain_slot'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
  }

  private async slotsOf(rosterId: string) {
    return this.db
      .selectFrom('roster_slots')
      .select(['slot_index', 'token_mint'])
      .where('roster_id', '=', rosterId)
      .orderBy('slot_index')
      .execute();
  }

  /** Creates the roster and the user's league entry on first draft. */
  private async ensure(userId: string, mode: SportMode): Promise<RosterRow> {
    const existing = await this.find(userId, mode);
    if (existing) return existing;

    await this.db
      .insertInto('rosters')
      .values({
        user_id: userId,
        sport_mode: mode,
        formation: mode === 'football' ? DEFAULT_FORMATION : null,
      })
      .onConflict((oc) => oc.columns(['user_id', 'sport_mode']).doNothing())
      .execute();
    await this.db
      .insertInto('classic_scores')
      .values({ user_id: userId, sport_mode: mode })
      .onConflict((oc) => oc.columns(['user_id', 'sport_mode']).doNothing())
      .execute();

    const created = await this.find(userId, mode);
    if (!created) throw new BadRequestException('Could not create the roster');
    return created;
  }
}

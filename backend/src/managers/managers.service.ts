import { BadRequestException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { BALANCE_SOURCE, PRICE_SOURCE } from '../core/sources.js';
import type { BalanceSource, PriceSource } from '../core/sources.js';
import type { AuthUser, ManagerDto, ManagerHoldingDto } from '../domain/dto.js';
import { rosterShape } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { LeagueService } from '../league/league.service.js';
import { NotificationsService } from '../notifications/notifications.service.js';
import { XStocksService } from '../xstocks/xstocks.service.js';

/**
 * Other players' public profiles, and following them.
 *
 * A wallet's contents are public on Solana, so a manager's holdings are
 * readable by anyone. "Adopting" one is not a transfer and needs nothing from
 * the manager: the viewer simply buys the same stocks with their own money,
 * signing each swap themselves.
 */
@Injectable()
export class ManagersService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(BALANCE_SOURCE) private readonly balances: BalanceSource,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
    private readonly xstocks: XStocksService,
    private readonly league: LeagueService,
    private readonly notifications: NotificationsService,
  ) {}

  async profile(viewer: AuthUser, userId: string, mode: SportMode): Promise<ManagerDto> {
    const user = await this.db
      .selectFrom('users')
      .select(['id', 'username', 'bio', 'wallet_address'])
      .where('id', '=', userId)
      .executeTakeFirst();
    if (!user) throw new NotFoundException('No such player');

    const [standing, holdings, lineup, followers, following, record] = await Promise.all([
      this.league.standing(user.id, mode),
      this.holdingsOf(user.wallet_address, user.id, mode),
      this.lineupOf(user.id, mode),
      this.followerCount(user.id),
      this.isFollowing(viewer.id, user.id),
      this.leagueRecord(user.id, mode),
    ]);

    return {
      userId: user.id,
      username: user.username,
      bio: user.bio,
      walletAddress: user.wallet_address,
      mode,
      rank: standing?.rank ?? null,
      points: standing?.points ?? 0,
      todayPoints: standing?.todayPoints ?? 0,
      streak: standing?.streak ?? 0,
      leaguesWon: record.won,
      leaguesPlayed: record.played,
      lineup,
      holdings,
      followers,
      following,
      isCurrentUser: user.id === viewer.id,
    };
  }

  async follow(viewer: AuthUser, userId: string): Promise<{ following: true }> {
    if (viewer.id === userId) {
      throw new BadRequestException("You can't follow yourself");
    }
    const inserted = await this.db
      .insertInto('follows')
      .values({ follower_id: viewer.id, followee_id: userId })
      .onConflict((oc) => oc.columns(['follower_id', 'followee_id']).doNothing())
      .returning('followee_id')
      .executeTakeFirst();

    // Only notify on a genuinely new follow, not a repeated tap.
    if (inserted) {
      const me = await this.db
        .selectFrom('users')
        .select('username')
        .where('id', '=', viewer.id)
        .executeTakeFirst();
      await this.notifications.push({
        userId,
        kind: 'new_follower',
        title: `${me?.username ?? 'Someone'} is following you`,
        body: 'They will see when you change your starting lineup.',
        data: { userId: viewer.id },
      });
    }
    return { following: true };
  }

  async unfollow(viewer: AuthUser, userId: string): Promise<{ following: false }> {
    await this.db
      .deleteFrom('follows')
      .where('follower_id', '=', viewer.id)
      .where('followee_id', '=', userId)
      .execute();
    return { following: false };
  }

  /** Tells a manager's followers that their lineup changed. */
  async announceMove(
    userId: string,
    mode: SportMode,
    { off, on }: { off: string; on: string },
  ): Promise<void> {
    const [followers, user] = await Promise.all([
      this.db
        .selectFrom('follows')
        .select('follower_id')
        .where('followee_id', '=', userId)
        .execute(),
      this.db
        .selectFrom('users')
        .select('username')
        .where('id', '=', userId)
        .executeTakeFirst(),
    ]);
    if (followers.length === 0) return;

    await this.notifications.pushMany(
      followers.map((f) => ({
        userId: f.follower_id,
        kind: 'manager_move' as const,
        title: `${user?.username ?? 'A manager'} made a change`,
        body: `${off} out, ${on} in for their ${mode.replace('_', ' ')} team.`,
        data: { userId, mode },
      })),
    );
  }

  /** Every eligible xStock in the manager's wallet, priced. */
  private async holdingsOf(
    wallet: string,
    userId: string,
    mode: SportMode,
  ): Promise<ManagerHoldingDto[]> {
    const [balances, stocks, starting] = await Promise.all([
      this.balances.getBalances(wallet),
      this.xstocks.byMint(),
      this.startingMints(userId, mode),
    ]);
    const held = [...balances].filter(([mint, amount]) => stocks.has(mint) && amount > 0);
    const priced = await this.prices.getPrices(held.map(([mint]) => mint));

    return held
      .flatMap(([mint, balance]) => {
        const row = stocks.get(mint);
        if (!row) return [];
        const dto = this.xstocks.toDto(row, priced.get(mint));
        return [
          {
            stock: dto,
            balance,
            valueUsd: balance * dto.priceUsd,
            starting: starting.has(mint),
          },
        ];
      })
      .sort((a, b) => b.valueUsd - a.valueUsd);
  }

  private async startingMints(userId: string, mode: SportMode): Promise<Set<string>> {
    const roster = await this.db
      .selectFrom('rosters')
      .select('id')
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    if (!roster) return new Set();
    const slots = await this.db
      .selectFrom('roster_slots')
      .select('token_mint')
      .where('roster_id', '=', roster.id)
      .execute();
    return new Set(slots.map((s) => s.token_mint));
  }

  private async lineupOf(userId: string, mode: SportMode) {
    const roster = await this.db
      .selectFrom('rosters')
      .select(['id', 'formation'])
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();
    if (!roster) return [];

    const slots = await this.db
      .selectFrom('roster_slots')
      .select(['slot_index', 'token_mint'])
      .where('roster_id', '=', roster.id)
      .orderBy('slot_index')
      .execute();
    if (slots.length === 0) return [];

    const shape = rosterShape(mode, roster.formation);
    const stocks = await this.xstocks.byMint();
    const priced = await this.prices.getPrices(slots.map((s) => s.token_mint));

    return slots.flatMap((slot) => {
      const row = stocks.get(slot.token_mint);
      const position = shape[slot.slot_index];
      if (!row || !position) return [];
      return [
        {
          slotIndex: slot.slot_index,
          positionLabel: position.label,
          stock: this.xstocks.toDto(row, priced.get(slot.token_mint)),
          // Another player's exact share count isn't the point, and showing it
          // invites copying position sizes rather than picks.
          balance: 0,
        },
      ];
    });
  }

  private async leagueRecord(userId: string, mode: SportMode) {
    const rows = await this.db
      .selectFrom('score_entries')
      .innerJoin('leagues', 'leagues.id', 'score_entries.context_id')
      .select(['score_entries.context_id as league_id', 'score_entries.final_points as points'])
      .where('score_entries.context', '=', 'league')
      .where('score_entries.user_id', '=', userId)
      .where('leagues.sport_mode', '=', mode)
      .where('leagues.status', '=', 'final')
      .execute();

    let won = 0;
    for (const row of rows) {
      const best = await this.db
        .selectFrom('score_entries')
        .select((eb) => eb.fn.max('final_points').as('best'))
        .where('context', '=', 'league')
        .where('context_id', '=', row.league_id)
        .executeTakeFirst();
      if (best?.best !== null && best?.best !== undefined && row.points === best.best) won++;
    }
    return { won, played: rows.length };
  }

  private async followerCount(userId: string): Promise<number> {
    const row = await this.db
      .selectFrom('follows')
      .select((eb) => eb.fn.countAll<string>().as('count'))
      .where('followee_id', '=', userId)
      .executeTakeFirst();
    return Number(row?.count ?? 0);
  }

  private async isFollowing(viewerId: string, userId: string): Promise<boolean> {
    const row = await this.db
      .selectFrom('follows')
      .select('followee_id')
      .where('follower_id', '=', viewerId)
      .where('followee_id', '=', userId)
      .executeTakeFirst();
    return row !== undefined;
  }
}

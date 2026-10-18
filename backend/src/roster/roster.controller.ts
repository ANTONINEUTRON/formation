import {
  Body,
  Controller,
  Get,
  Inject,
  Param,
  ParseIntPipe,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import { ChainService } from '../core/chain.service.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { counts } from '../domain/holdings.js';
import type { AuthUser, FormationChangeDto, RosterDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { requireString } from '../domain/validate.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { RosterService } from './roster.service.js';

@Controller('roster')
@UseGuards(AuthGuard)
export class RosterController {
  constructor(private readonly rosters: RosterService) {}

  @Get(':mode')
  get(@Param('mode') mode: string, @CurrentUser() user: AuthUser): Promise<RosterDto> {
    return this.rosters.getRoster(user, parseSportMode(mode));
  }

  @Put(':mode/slots/:slotIndex')
  fill(
    @Param('mode') mode: string,
    @Param('slotIndex', ParseIntPipe) slotIndex: number,
    @Body() body: { mint?: string },
    @CurrentUser() user: AuthUser,
  ): Promise<RosterDto> {
    return this.rosters.fillSlot(
      user,
      parseSportMode(mode),
      slotIndex,
      requireString(body.mint, 'mint'),
    );
  }

  /** "Use what I hold": fills an empty team from the wallet's own stocks. */
  @Post(':mode/from-holdings')
  fromHoldings(@Param('mode') mode: string, @CurrentUser() user: AuthUser): Promise<RosterDto> {
    return this.rosters.fillFromHoldings(user, parseSportMode(mode));
  }

  /** Football: change shape, e.g. {"formation": "3-5-2"}. */
  @Put(':mode/formation')
  formation(
    @Param('mode') mode: string,
    @Body() body: { formation?: string },
    @CurrentUser() user: AuthUser,
  ): Promise<FormationChangeDto> {
    return this.rosters.setFormation(user, parseSportMode(mode), body?.formation);
  }

  /** Football and basketball: {"captainSlot": 9, "viceCaptainSlot": 0}. */
  @Put(':mode/captain')
  captain(
    @Param('mode') mode: string,
    @Body() body: unknown,
    @CurrentUser() user: AuthUser,
  ): Promise<RosterDto> {
    return this.rosters.setCaptaincy(user, parseSportMode(mode), body);
  }
}

@Controller('wallet')
@UseGuards(AuthGuard)
export class WalletController {
  constructor(
    @Inject(CONFIG) private readonly config: AppConfig,
    private readonly chain: ChainService,
    private readonly xstocks: XStocksService,
  ) {}

  /**
   * The user's xStock balances, keyed by mint: only holdings that count
   * (worth at least MIN_HOLDING_USD), so the app never offers dust as held.
   */
  @Get('balances')
  async balances(@CurrentUser() user: AuthUser) {
    const [balances, stocks] = await Promise.all([
      this.chain.getBalances(user.walletAddress),
      this.xstocks.byMint(),
    ]);
    const owned = [...balances].filter(([mint, amount]) => stocks.has(mint) && amount > 0);
    const prices = await this.chain.getPrices(owned.map(([mint]) => mint));
    return {
      balances: Object.fromEntries(
        owned.filter(([mint, amount]) => counts(amount, prices.get(mint)?.usdPrice, this.config.minHoldingUsd)),
      ),
    };
  }
}

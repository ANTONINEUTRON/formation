import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Put,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import { ChainService } from '../core/chain.service.js';
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
    private readonly chain: ChainService,
    private readonly xstocks: XStocksService,
  ) {}

  /** The user's xStock balances, keyed by mint. */
  @Get('balances')
  async balances(@CurrentUser() user: AuthUser) {
    const [balances, stocks] = await Promise.all([
      this.chain.getBalances(user.walletAddress),
      this.xstocks.byMint(),
    ]);
    return {
      balances: Object.fromEntries(
        [...balances].filter(([mint, amount]) => stocks.has(mint) && amount > 0),
      ),
    };
  }
}

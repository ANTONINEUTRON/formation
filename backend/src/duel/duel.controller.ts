import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AdminGuard, AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, DuelDto, TrophyDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { requireNumber, requireString } from '../domain/validate.js';
import { GameweekService } from '../gameweek/gameweek.service.js';
import { PriceTickService } from '../scoring/price-tick.service.js';
import { TrophyService } from '../trophy/trophy.service.js';
import { DuelService } from './duel.service.js';

@Controller('duels')
@UseGuards(AuthGuard)
export class DuelController {
  constructor(private readonly duels: DuelService) {}

  @Get()
  list(@Query('mode') mode: string, @CurrentUser() user: AuthUser): Promise<DuelDto[]> {
    return this.duels.list(user, parseSportMode(mode));
  }

  @Post()
  create(
    @Body() body: { mode?: string; opponent?: string; durationHours?: number },
    @CurrentUser() user: AuthUser,
  ): Promise<DuelDto> {
    return this.duels.create(
      user,
      parseSportMode(requireString(body.mode, 'mode')),
      requireString(body.opponent, 'opponent'),
      requireNumber(body.durationHours, 'durationHours'),
    );
  }

  @Post(':id/accept')
  accept(@Param('id') id: string, @CurrentUser() user: AuthUser): Promise<DuelDto> {
    return this.duels.respond(user, id, true);
  }

  @Post(':id/decline')
  decline(@Param('id') id: string, @CurrentUser() user: AuthUser): Promise<DuelDto> {
    return this.duels.respond(user, id, false);
  }
}

@Controller('trophies')
@UseGuards(AuthGuard)
export class TrophyController {
  constructor(private readonly trophies: TrophyService) {}

  @Get()
  list(@CurrentUser() user: AuthUser): Promise<TrophyDto[]> {
    return this.trophies.list(user.id);
  }
}

/** Demo controls so scoring can be driven on stage. */
@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(
    private readonly priceTicks: PriceTickService,
    private readonly gameweeks: GameweekService,
    private readonly duels: DuelService,
  ) {}

  /** Records prices now, then opens, scores and closes gameweeks. */
  @Post('tick')
  tick() {
    return this.priceTicks.tick();
  }

  /** Closes the current gameweek early and opens the next one. */
  @Post('gameweeks/:mode/advance')
  advance(@Param('mode') mode: string) {
    return this.gameweeks.advance(parseSportMode(mode));
  }

  @Post('duels/:id/settle')
  settle(@Param('id') id: string): Promise<DuelDto> {
    return this.duels.settle(id);
  }
}

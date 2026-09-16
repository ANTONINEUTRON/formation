import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AdminGuard, AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, DuelDto, TrophyDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { requireNumber, requireString } from '../domain/validate.js';
import { ScoringService } from '../scoring/scoring.service.js';
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

/** Demo controls so the hourly tick and duel settlement can run on stage. */
@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(
    private readonly scoring: ScoringService,
    private readonly duels: DuelService,
  ) {}

  @Post('tick')
  tick() {
    return this.scoring.runTick();
  }

  @Post('duels/:id/settle')
  settle(@Param('id') id: string): Promise<DuelDto> {
    return this.duels.settle(id);
  }
}

import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, GameweekDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { GameweekService } from './gameweek.service.js';

@Controller('gameweeks')
@UseGuards(AuthGuard)
export class GameweekController {
  constructor(private readonly gameweeks: GameweekService) {}

  @Get(':mode/current')
  async current(
    @Param('mode') mode: string,
    @CurrentUser() user: AuthUser,
  ): Promise<GameweekDto | null> {
    const gameweek = await this.gameweeks.current(parseSportMode(mode));
    return gameweek ? this.gameweeks.dtoFor(gameweek, user.id) : null;
  }

  @Get(':mode/history')
  async history(
    @Param('mode') mode: string,
    @CurrentUser() user: AuthUser,
  ): Promise<GameweekDto[]> {
    const gameweeks = await this.gameweeks.history(parseSportMode(mode));
    return Promise.all(gameweeks.map((gw) => this.gameweeks.dtoFor(gw, user.id)));
  }
}

import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { CurrentUser, OptionalAuthGuard } from '../auth/auth.guard.js';
import type { AuthUser, LeaderboardEntryDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { LeagueService } from './league.service.js';

@Controller('league')
export class LeagueController {
  constructor(private readonly league: LeagueService) {}

  @Get(':mode')
  @UseGuards(OptionalAuthGuard)
  leaderboard(
    @Param('mode') mode: string,
    @CurrentUser() user?: AuthUser,
  ): Promise<LeaderboardEntryDto[]> {
    return this.league.leaderboard(parseSportMode(mode), user?.id);
  }
}

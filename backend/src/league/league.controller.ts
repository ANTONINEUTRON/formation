import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { CurrentUser, OptionalAuthGuard } from '../auth/auth.guard.js';
import type { AuthUser, LeaderboardEntryDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { LeagueService } from './league.service.js';

@Controller('league')
export class LeagueController {
  constructor(private readonly league: LeagueService) {}

  /**
   * `?period=all_time|monthly|weekly|custom`, defaulting to all time.
   * Custom ranges take `?from=<iso>&to=<iso>`; `to` may be omitted to run
   * through to now.
   */
  @Get(':mode')
  @UseGuards(OptionalAuthGuard)
  leaderboard(
    @Param('mode') mode: string,
    @Query('period') period?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @CurrentUser() user?: AuthUser,
  ): Promise<LeaderboardEntryDto[]> {
    // The period is resolved inside the service, which owns the clock.
    return this.league.leaderboard(parseSportMode(mode), user?.id, { period, from, to });
  }
}

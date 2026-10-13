import { BadRequestException, Controller, Get, Inject, Param, Query, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import type { AuthUser, MatchWeekResultDto, PortfolioHealthDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { MatchWeekService } from './match-week.service.js';
import { PortfolioService } from './portfolio.service.js';

@Controller('match-week')
@UseGuards(AuthGuard)
export class MatchWeekController {
  constructor(
    private readonly matchWeeks: MatchWeekService,
    private readonly portfolio: PortfolioService,
    @Inject(CLOCK) private readonly clock: Clock,
  ) {}

  /**
   * The signed-in player's match week result card: this week (live) by
   * default, or `?week=<number>` for a past one.
   */
  @Get(':mode/result')
  result(
    @Param('mode') mode: string,
    @Query('week') week: string | undefined,
    @CurrentUser() user: AuthUser,
  ): Promise<MatchWeekResultDto> {
    const number = week === undefined || week === '' ? undefined : Number(week);
    if (number !== undefined && (!Number.isInteger(number) || number < 1)) {
      throw new BadRequestException('week must be a positive whole number');
    }
    return this.matchWeeks.result(user.id, parseSportMode(mode), this.clock.now(), number);
  }

  /** The Assistant Manager's portfolio health card for this match week. */
  @Get(':mode/health')
  health(@Param('mode') mode: string, @CurrentUser() user: AuthUser): Promise<PortfolioHealthDto> {
    return this.portfolio.health(user.id, parseSportMode(mode), this.clock.now());
  }
}

import { Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser, OptionalAuthGuard } from '../auth/auth.guard.js';
import type { AuthUser, ManagerDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { OgRateLimitGuard } from '../og/og.controller.js';
import { ManagersService } from './managers.service.js';

@Controller('managers')
export class ManagersController {
  constructor(private readonly managers: ManagersService) {}

  /**
   * Another player's profile, lineup and holdings for one sport.
   *
   * Open to guests, so a shared link shows the team before the visitor has a
   * wallet; everything on it is public on chain anyway. Rate limited per IP,
   * like the link previews, so it can't be used to walk every user id.
   */
  @Get(':userId')
  @UseGuards(OptionalAuthGuard, OgRateLimitGuard)
  profile(
    @Param('userId') userId: string,
    @Query('mode') mode: string,
    @CurrentUser() user: AuthUser | undefined,
  ): Promise<ManagerDto> {
    return this.managers.profile(user ?? null, userId, parseSportMode(mode));
  }

  @Post(':userId/follow')
  @UseGuards(AuthGuard)
  follow(@Param('userId') userId: string, @CurrentUser() user: AuthUser) {
    return this.managers.follow(user, userId);
  }

  @Delete(':userId/follow')
  @UseGuards(AuthGuard)
  unfollow(@Param('userId') userId: string, @CurrentUser() user: AuthUser) {
    return this.managers.unfollow(user, userId);
  }
}

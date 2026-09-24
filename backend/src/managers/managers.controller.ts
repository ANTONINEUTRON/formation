import { Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, ManagerDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { ManagersService } from './managers.service.js';

@Controller('managers')
@UseGuards(AuthGuard)
export class ManagersController {
  constructor(private readonly managers: ManagersService) {}

  /** Another player's profile, lineup and holdings for one sport. */
  @Get(':userId')
  profile(
    @Param('userId') userId: string,
    @Query('mode') mode: string,
    @CurrentUser() user: AuthUser,
  ): Promise<ManagerDto> {
    return this.managers.profile(user, userId, parseSportMode(mode));
  }

  @Post(':userId/follow')
  follow(@Param('userId') userId: string, @CurrentUser() user: AuthUser) {
    return this.managers.follow(user, userId);
  }

  @Delete(':userId/follow')
  unfollow(@Param('userId') userId: string, @CurrentUser() user: AuthUser) {
    return this.managers.unfollow(user, userId);
  }
}

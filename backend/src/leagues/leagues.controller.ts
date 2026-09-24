import { Body, Controller, Delete, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, LeagueDto } from '../domain/dto.js';
import { parseSportMode } from '../domain/sport.js';
import { requireNumber, requireString } from '../domain/validate.js';
import { LeaguesService } from './leagues.service.js';

@Controller('leagues')
@UseGuards(AuthGuard)
export class LeaguesController {
  constructor(private readonly leagues: LeaguesService) {}

  /** Public leagues open to join, plus every league you're already in. */
  @Get()
  list(@Query('mode') mode: string, @CurrentUser() user: AuthUser): Promise<LeagueDto[]> {
    return this.leagues.list(user, parseSportMode(mode));
  }

  @Get(':id')
  byId(@Param('id') id: string, @CurrentUser() user: AuthUser): Promise<LeagueDto> {
    return this.leagues.byId(user, id);
  }

  /**
   * Creates a league. Passing `opponent` with `maxMembers: 2` is how a PvP
   * duel is created — it is the same object underneath.
   */
  @Post()
  create(
    @Body()
    body: {
      name?: string;
      mode?: string;
      visibility?: string;
      startsAt?: string;
      durationHours?: number;
      maxMembers?: number | null;
      opponent?: string;
    },
    @CurrentUser() user: AuthUser,
  ): Promise<LeagueDto> {
    const startsAt = new Date(body.startsAt ?? '');
    if (Number.isNaN(startsAt.getTime())) {
      throw new Error('startsAt must be an ISO date');
    }
    return this.leagues.create(user, {
      name: requireString(body.name, 'name'),
      mode: parseSportMode(requireString(body.mode, 'mode')),
      visibility: body.visibility === 'private' ? 'private' : 'public',
      startsAt,
      durationHours: requireNumber(body.durationHours, 'durationHours'),
      maxMembers: body.maxMembers ?? null,
      invite: body.opponent,
    });
  }

  @Post('join')
  join(
    @Body() body: { id?: string; code?: string },
    @CurrentUser() user: AuthUser,
  ): Promise<LeagueDto> {
    return this.leagues.join(user, { id: body.id, code: body.code });
  }

  @Delete(':id/membership')
  leave(@Param('id') id: string, @CurrentUser() user: AuthUser): Promise<void> {
    return this.leagues.leave(user, id);
  }
}

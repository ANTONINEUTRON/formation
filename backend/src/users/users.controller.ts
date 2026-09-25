import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, ProfileDto } from '../domain/dto.js';
import { UsersService } from './users.service.js';

@Controller('users')
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser): Promise<ProfileDto> {
    return this.users.profile(user.id);
  }

  /**
   * Sets the player's name, bio and email. Each is optional, so the app can
   * send only what changed; passing null clears bio or email.
   *
   * Name and bio are public. Email is not — it is returned here, to its owner,
   * and nowhere else.
   */
  @Patch('me')
  update(
    @Body() body: { username?: string; bio?: string | null; email?: string | null },
    @CurrentUser() user: AuthUser,
  ): Promise<ProfileDto> {
    return this.users.updateProfile(user.id, body);
  }
}

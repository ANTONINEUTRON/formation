import { Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, NotificationDto } from '../domain/dto.js';
import { NotificationsService } from './notifications.service.js';

@Controller('notifications')
@UseGuards(AuthGuard)
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  list(@CurrentUser() user: AuthUser): Promise<NotificationDto[]> {
    return this.notifications.list(user.id);
  }

  /** Cheap poll for the bell badge. */
  @Get('unread-count')
  async unread(@CurrentUser() user: AuthUser): Promise<{ count: number }> {
    return { count: await this.notifications.unreadCount(user.id) };
  }

  @Post('read-all')
  async readAll(@CurrentUser() user: AuthUser): Promise<{ ok: true }> {
    await this.notifications.markAllRead(user.id);
    return { ok: true };
  }

  @Post(':id/read')
  async read(
    @Param('id') id: string,
    @CurrentUser() user: AuthUser,
  ): Promise<{ ok: true }> {
    await this.notifications.markRead(user.id, id);
    return { ok: true };
  }
}

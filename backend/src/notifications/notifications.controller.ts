import { Body, Controller, Delete, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, NotificationDto, PushSettingsDto } from '../domain/dto.js';
import { NotificationsService } from './notifications.service.js';
import { PushService } from './push.service.js';

@Controller('notifications')
@UseGuards(AuthGuard)
export class NotificationsController {
  constructor(
    private readonly notifications: NotificationsService,
    private readonly push: PushService,
  ) {}

  /** Registers this device for pushes: `{ token, platform, timeZone? }`. */
  @Post('devices')
  async registerDevice(
    @Body() body: { token?: unknown; platform?: unknown; timeZone?: unknown },
    @CurrentUser() user: AuthUser,
  ): Promise<{ ok: true }> {
    await this.push.registerDevice(user.id, body ?? {});
    return { ok: true };
  }

  @Delete('devices/:token')
  async unregisterDevice(
    @Param('token') token: string,
    @CurrentUser() user: AuthUser,
  ): Promise<{ ok: true }> {
    await this.push.unregisterDevice(user.id, token);
    return { ok: true };
  }

  @Get('settings')
  settings(@CurrentUser() user: AuthUser): Promise<PushSettingsDto> {
    return this.push.settings(user.id);
  }

  /** Any of: categories, quietEnabled, quietStart, quietEnd, timeZone. */
  @Put('settings')
  saveSettings(
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: AuthUser,
  ): Promise<PushSettingsDto> {
    return this.push.saveSettings(user.id, body ?? {});
  }

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

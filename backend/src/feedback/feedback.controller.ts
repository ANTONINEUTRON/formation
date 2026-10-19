import { Body, Controller, Post, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { MAX_PHOTO_BYTES } from '../assistant/avatars.js';
import type { UploadedPhoto } from '../assistant/avatars.js';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser } from '../domain/dto.js';
import { FeedbackService } from './feedback.service.js';

@Controller('feedback')
@UseGuards(AuthGuard)
export class FeedbackController {
  constructor(private readonly feedback: FeedbackService) {}

  /**
   * multipart/form-data: kind (bug, idea or other), message, rating (1-5,
   * optional), appVersion and platform (optional), screenshot (JPEG, PNG or
   * WebP, 5 MB max, optional). The reply address is the profile email.
   */
  @Post()
  @UseInterceptors(FileInterceptor('screenshot', { limits: { fileSize: MAX_PHOTO_BYTES } }))
  submit(
    @UploadedFile() screenshot: UploadedPhoto | undefined,
    @Body() body: Record<string, unknown>,
    @CurrentUser() user: AuthUser,
  ): Promise<{ id: string }> {
    return this.feedback.submit(user, body ?? {}, screenshot);
  }
}

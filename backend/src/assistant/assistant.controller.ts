import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Res,
  StreamableFile,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser } from '../domain/dto.js';
import { AssistantService } from './assistant.service.js';
import type { AssistantProfileDto, AssistantReplyDto } from './assistant.service.js';
import { AvatarService, MAX_PHOTO_BYTES } from './avatars.js';
import type { UploadedPhoto } from './avatars.js';
import { PurchasesService } from './purchases.service.js';
import type { CreditQuoteDto } from './purchases.service.js';
import { StarterService } from './starter.js';
import type { StarterSquadDto } from './starter.js';

/**
 * The Assistant Manager. The user is the Manager; the assistant advises and
 * every change it suggests is applied by the Manager through the roster
 * endpoints, never by the assistant itself.
 */
@Controller('assistant')
@UseGuards(AuthGuard)
export class AssistantController {
  constructor(
    private readonly assistant: AssistantService,
    private readonly purchases: PurchasesService,
    private readonly starterSquads: StarterService,
    private readonly avatars: AvatarService,
  ) {}

  /** The chosen character (null until picked), the presets, and the credit balance. */
  @Get()
  profile(@CurrentUser() user: AuthUser): Promise<AssistantProfileDto> {
    return this.assistant.profile(user);
  }

  /** {"characterId": "mentor"} */
  @Put('character')
  character(
    @Body() body: { characterId?: unknown },
    @CurrentUser() user: AuthUser,
  ): Promise<AssistantProfileDto> {
    return this.assistant.setCharacter(user, body?.characterId);
  }

  /**
   * {"context": {"mode": "football", "screen": "team", "focus": {"mint": "..."}},
   *  "messages": [{"role": "manager", "text": "Who should I captain?"}]}
   *
   * Costs one credit; 402 when there are none, 502 (uncharged) when the model fails.
   */
  @Post('chat')
  chat(@Body() body: unknown, @CurrentUser() user: AuthUser): Promise<AssistantReplyDto> {
    return this.assistant.chat(user, body);
  }

  // ── Free starter squad ─────────────────────────────────────────────────────

  /** {"mode": "basketball", "budgetUsd": 10, "style": "safe"} -> a complete squad to review. Free, twice. */
  @Post('starter')
  starter(@Body() body: unknown, @CurrentUser() user: AuthUser): Promise<StarterSquadDto> {
    return this.starterSquads.draft(user, body);
  }

  /** The Manager will build their own team; the free draft is used up. */
  @Post('starter/dismiss')
  dismissStarter(@CurrentUser() user: AuthUser): Promise<{ draftsLeft: number }> {
    return this.starterSquads.dismiss(user);
  }

  // ── Custom avatar from a photo ─────────────────────────────────────────────

  /**
   * multipart/form-data: photo (JPEG/PNG/WebP, 5 MB max), personality (a
   * preset id), name (optional), consent ("true"). The photo is never stored.
   */
  @Post('avatar')
  @UseInterceptors(FileInterceptor('photo', { limits: { fileSize: MAX_PHOTO_BYTES } }))
  createAvatar(
    @UploadedFile() photo: UploadedPhoto | undefined,
    @Body() body: { personality?: unknown; name?: unknown; consent?: unknown },
    @CurrentUser() user: AuthUser,
  ): Promise<{ credits: number }> {
    return this.avatars.create(user, photo, body ?? {});
  }

  /** The Manager's own custom avatar in one pose, as an image. */
  @Get('avatar/:pose')
  async avatar(
    @Param('pose') pose: string,
    @CurrentUser() user: AuthUser,
    @Res({ passthrough: true }) res: { setHeader(name: string, value: string): void },
  ): Promise<StreamableFile> {
    const image = await this.avatars.image(user, pose);
    res.setHeader('Content-Type', image.mime);
    // Private to this Manager; the app busts the cache with avatarVersion.
    res.setHeader('Cache-Control', 'private, max-age=86400');
    return new StreamableFile(image.data);
  }

  // ── Buying credits with SKR ────────────────────────────────────────────────

  /** {"packId": "credits-100"} -> the SKR price, held for two minutes. */
  @Post('credits/quote')
  quote(@Body() body: { packId?: unknown }, @CurrentUser() user: AuthUser): Promise<CreditQuoteDto> {
    return this.purchases.quote(user, body?.packId);
  }

  /** {"quoteId": "..."} -> an unsigned SKR transfer (base64) for the wallet to sign. */
  @Post('credits/build')
  build(@Body() body: { quoteId?: unknown }, @CurrentUser() user: AuthUser): Promise<{ transaction: string }> {
    return this.purchases.build(user, body?.quoteId);
  }

  /** {"quoteId": "...", "signature": "..."} -> the new balance, once the payment checks out. */
  @Post('credits/confirm')
  confirm(
    @Body() body: { quoteId?: unknown; signature?: unknown },
    @CurrentUser() user: AuthUser,
  ): Promise<{ credits: number }> {
    return this.purchases.confirm(user, body ?? {});
  }
}

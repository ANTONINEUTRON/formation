import { Body, Controller, Get, Post, Put, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser } from '../domain/dto.js';
import { AssistantService } from './assistant.service.js';
import type { AssistantProfileDto, AssistantReplyDto } from './assistant.service.js';

/**
 * The Assistant Manager. The user is the Manager; the assistant advises and
 * every change it suggests is applied by the Manager through the roster
 * endpoints, never by the assistant itself.
 */
@Controller('assistant')
@UseGuards(AuthGuard)
export class AssistantController {
  constructor(private readonly assistant: AssistantService) {}

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
}

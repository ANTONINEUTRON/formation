import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser } from '../domain/dto.js';
import { requireNumber, requireString } from '../domain/validate.js';
import { SwapService } from './swap.service.js';

@Controller('swap')
@UseGuards(AuthGuard)
export class SwapController {
  constructor(private readonly swaps: SwapService) {}

  @Post('quote')
  quote(
    @Body() body: { mint?: string; usdcAmount?: number },
    @CurrentUser() user: AuthUser,
  ) {
    return this.swaps.quote(
      user,
      requireString(body.mint, 'mint'),
      requireNumber(body.usdcAmount, 'usdcAmount'),
    );
  }

  @Post('build')
  build(@Body() body: { quoteId?: string }, @CurrentUser() user: AuthUser) {
    return this.swaps.build(user, requireString(body.quoteId, 'quoteId'));
  }

  @Post('confirm')
  confirm(@Body() body: { signature?: string }, @CurrentUser() user: AuthUser) {
    return this.swaps.confirm(user, requireString(body.signature, 'signature'));
  }
}

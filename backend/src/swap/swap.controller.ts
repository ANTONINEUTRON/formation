import { BadRequestException, Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { AuthGuard, CurrentUser } from '../auth/auth.guard.js';
import type { AuthUser, PayTokenDto } from '../domain/dto.js';
import { parsePaySymbol } from '../domain/pay-tokens.js';
import { requireNumber, requireString } from '../domain/validate.js';
import { SwapService } from './swap.service.js';

@Controller('swap')
@UseGuards(AuthGuard)
export class SwapController {
  constructor(private readonly swaps: SwapService) {}

  /** What this server accepts as payment. SKR appears only once configured. */
  @Get('tokens')
  tokens(): PayTokenDto[] {
    return this.swaps.payTokens.map(({ symbol, mint, decimals }) => ({
      symbol,
      mint,
      decimals,
    }));
  }

  @Post('quote')
  quote(
    @Body() body: { mint?: string; amount?: number; payWith?: string },
    @CurrentUser() user: AuthUser,
  ) {
    let payWith;
    try {
      payWith = parsePaySymbol(body.payWith);
    } catch (e) {
      throw new BadRequestException((e as Error).message);
    }
    return this.swaps.quote(
      user,
      requireString(body.mint, 'mint'),
      requireNumber(body.amount, 'amount'),
      payWith,
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

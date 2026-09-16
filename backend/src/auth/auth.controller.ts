import { Body, Controller, Post } from '@nestjs/common';
import { requireString } from '../domain/validate.js';
import { AuthService } from './auth.service.js';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /** Returns the message the wallet must sign. */
  @Post('challenge')
  challenge(@Body() body: { walletAddress?: string }) {
    return this.auth.createChallenge(
      requireString(body.walletAddress, 'walletAddress'),
    );
  }

  /** Exchanges a base58 signature of the challenge for a bearer token. */
  @Post('verify')
  verify(@Body() body: { walletAddress?: string; signature?: string }) {
    return this.auth.verify(
      requireString(body.walletAddress, 'walletAddress'),
      requireString(body.signature, 'signature'),
    );
  }
}

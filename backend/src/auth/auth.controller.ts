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

  /**
   * Exchanges a signed Sign In With Solana message for a bearer token.
   *
   * The web app's sign-in: the wallet connects and signs in one step, which
   * Android Chrome requires — it blocks a second hop to the wallet that a tap
   * did not start.
   */
  @Post('siws')
  siws(@Body() body: { walletAddress?: string; message?: string; signature?: string }) {
    return this.auth.verifySiws(
      requireString(body.walletAddress, 'walletAddress'),
      requireString(body.message, 'message'),
      requireString(body.signature, 'signature'),
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

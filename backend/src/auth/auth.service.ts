import {
  BadRequestException,
  Inject,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { PublicKey } from '@solana/web3.js';
import bs58 from 'bs58';
import { randomBytes } from 'node:crypto';
import nacl from 'tweetnacl';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { UsersService } from '../users/users.service.js';
import { parseSiwsMessage, SIWS_MAX_AGE_MS, siwsProblem } from './siws.js';
import { signToken, TokenPayload, verifyToken } from './token.js';

const CHALLENGE_TTL_MS = 5 * 60_000;
const TOKEN_TTL_MS = 30 * 24 * 60 * 60_000;

/**
 * Sign-in with a Solana wallet: the app signs a one-time message with the
 * wallet (MWA signMessages) and gets back a bearer token.
 */
@Injectable()
export class AuthService {
  // In-memory: fine for a single backend instance.
  private readonly challenges = new Map<
    string,
    { message: string; expires: number }
  >();
  /** SIWS nonces already accepted, until they are too old to matter. */
  private readonly usedNonces = new Map<string, number>();

  constructor(
    @Inject(CONFIG) private readonly config: AppConfig,
    private readonly users: UsersService,
  ) {}

  createChallenge(walletAddress: string): { message: string } {
    this.parseKey(walletAddress);
    const nonce = randomBytes(16).toString('hex');
    const message = `Sign in to Formation\nWallet: ${walletAddress}\nNonce: ${nonce}`;
    this.challenges.set(walletAddress, {
      message,
      expires: Date.now() + CHALLENGE_TTL_MS,
    });
    return { message };
  }

  async verify(walletAddress: string, signature: string) {
    const challenge = this.challenges.get(walletAddress);
    this.challenges.delete(walletAddress);
    if (!challenge || challenge.expires < Date.now()) {
      throw new UnauthorizedException('Sign-in challenge expired, try again');
    }

    let signatureBytes: Uint8Array;
    try {
      signatureBytes = bs58.decode(signature);
    } catch {
      throw new BadRequestException('signature must be base58');
    }
    const valid = nacl.sign.detached.verify(
      new TextEncoder().encode(challenge.message),
      signatureBytes,
      this.parseKey(walletAddress).toBytes(),
    );
    if (!valid) throw new UnauthorizedException('Invalid wallet signature');

    return this.issue(walletAddress);
  }

  /**
   * Signs in with a Sign In With Solana message the wallet built and signed.
   *
   * The web app's path, because it costs one hop to the wallet instead of two
   * — which matters on Android Chrome, where the second hop is blocked. See
   * siws.ts for what stands in for a server-issued challenge.
   */
  async verifySiws(walletAddress: string, messageBase64: string, signature: string) {
    const key = this.parseKey(walletAddress);
    const messageBytes = Buffer.from(messageBase64, 'base64');
    // A SIWS message is a few hundred bytes; anything far larger is not one.
    if (messageBytes.length === 0 || messageBytes.length > 2048) {
      throw new BadRequestException('message must be a base64 sign-in message');
    }

    const message = parseSiwsMessage(messageBytes.toString('utf8'));
    if (!message) throw new BadRequestException('Not a Sign In With Solana message');
    const problem = siwsProblem(message, walletAddress, this.config.webOrigins);
    if (problem) throw new UnauthorizedException(problem);

    let signatureBytes: Uint8Array;
    try {
      signatureBytes = bs58.decode(signature);
    } catch {
      throw new BadRequestException('signature must be base58');
    }
    if (!nacl.sign.detached.verify(messageBytes, signatureBytes, key.toBytes())) {
      throw new UnauthorizedException('Invalid wallet signature');
    }

    // Checked last, so a forged message cannot burn a real player's nonce.
    this.purgeNonces();
    if (this.usedNonces.has(message.nonce!)) {
      throw new UnauthorizedException('Sign-in already used, try again');
    }
    this.usedNonces.set(message.nonce!, Date.now() + 2 * SIWS_MAX_AGE_MS);

    return this.issue(walletAddress);
  }

  private purgeNonces() {
    const now = Date.now();
    for (const [nonce, expires] of this.usedNonces) {
      if (expires < now) this.usedNonces.delete(nonce);
    }
  }

  /** Creates the player if new and hands back a bearer token. */
  private async issue(walletAddress: string) {
    const user = await this.users.upsertByWallet(walletAddress);
    const token = signToken(
      { sub: user.id, wallet: walletAddress, exp: Date.now() + TOKEN_TTL_MS },
      this.secret(),
    );
    return {
      token,
      user: {
        id: user.id,
        username: user.username,
        walletAddress: user.wallet_address,
      },
    };
  }

  readToken(token: string): TokenPayload | null {
    return verifyToken(token, this.secret());
  }

  private secret(): string {
    if (!this.config.authSecret) {
      throw new ServiceUnavailableException('AUTH_SECRET is not configured');
    }
    return this.config.authSecret;
  }

  private parseKey(walletAddress: string): PublicKey {
    try {
      return new PublicKey(walletAddress);
    } catch {
      throw new BadRequestException('walletAddress is not a valid public key');
    }
  }
}

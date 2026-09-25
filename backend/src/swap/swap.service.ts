import {
  BadGatewayException,
  BadRequestException,
  GatewayTimeoutException,
  Inject,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { ChainService } from '../core/chain.service.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import type { AuthUser, SwapQuoteDto } from '../domain/dto.js';
import type { PaySymbol, PayToken } from '../domain/pay-tokens.js';
import { XStocksService } from '../xstocks/xstocks.service.js';

const QUOTE_TTL_MS = 60_000;
const SLIPPAGE_BPS = 100;

interface JupiterQuote {
  outAmount: string;
  priceImpactPct: string;
  [key: string]: unknown;
}

/**
 * Buys an xStock through Jupiter, paying with USDC, SOL or SKR. The backend
 * adds the platform fee and returns an unsigned transaction; the player's
 * wallet signs and sends it, so Formation never has custody of funds.
 */
@Injectable()
export class SwapService {
  private readonly logger = new Logger(SwapService.name);

  private readonly quotes = new Map<
    string,
    { quote: JupiterQuote; wallet: string; expires: number; feeAccount: string }
  >();

  constructor(
    @Inject(CONFIG) private readonly config: AppConfig,
    private readonly xstocks: XStocksService,
    private readonly chain: ChainService,
  ) {}

  /** The tokens this server is configured to accept. */
  get payTokens(): PayToken[] {
    return this.config.payTokens;
  }

  private payToken(symbol: PaySymbol): PayToken {
    const token = this.config.payTokens.find((t) => t.symbol === symbol);
    if (!token) throw new BadRequestException(`${symbol} is not accepted here`);
    return token;
  }

  /**
   * Jupiter rejects platformFeeBps without a fee account, and the account's
   * mint must match the input or output — so a token with no fee account of
   * its own charges nothing rather than failing the swap.
   */
  private feeBpsFor(token: PayToken): number {
    return token.feeAccount ? this.config.platformFeeBps : 0;
  }

  /**
   * Turns a failed Jupiter response into something a player can read.
   *
   * Jupiter's body is a JSON blob naming mints and routers; it belongs in the
   * log, never on screen. The status is worth separating too — a rate limit
   * reported as "no route for AAPLx" sends you hunting a routing problem that
   * isn't there, and tells the player to give up when they should just retry.
   */
  private async fail(res: Response, context: string): Promise<never> {
    const detail = await res.text().catch(() => '<no body>');
    this.logger.warn(`Jupiter ${context} failed: ${res.status} ${detail}`);

    if (res.status === 429) {
      throw new ServiceUnavailableException('Busy right now — try again in a moment.');
    }
    if (res.status >= 500) {
      throw new BadGatewayException('Jupiter is unavailable right now. Please try again.');
    }
    throw new BadGatewayException(`Could not price that trade: ${context}`);
  }

  async quote(
    user: AuthUser,
    mint: string,
    amount: number,
    paySymbol: PaySymbol = 'USDC',
  ): Promise<SwapQuoteDto> {
    const payToken = this.payToken(paySymbol);
    const feeBps = this.feeBpsFor(payToken);
    // No upper limit: it is the player's own money and their own wallet, and
    // Jupiter already rejects anything it cannot route. Only reject amounts
    // that aren't a usable number.
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Enter an amount greater than zero');
    }
    const stock = (await this.xstocks.byMint()).get(mint);
    if (!stock) throw new BadRequestException('Unsupported token');

    const params = new URLSearchParams({
      inputMint: payToken.mint,
      outputMint: mint,
      // Scale by the paying token's own decimals: USDC is 6, SOL is 9.
      amount: String(Math.round(amount * 10 ** payToken.decimals)),
      slippageBps: String(SLIPPAGE_BPS),
    });
    if (feeBps > 0) params.set('platformFeeBps', String(feeBps));

    const res = await fetch(`${this.config.jupiterApiUrl}/swap/v1/quote?${params}`, {
      headers: this.config.jupiterHeaders,
    });
    if (!res.ok) await this.fail(res, `no route for ${stock.symbol}`);
    const quote = (await res.json()) as JupiterQuote;

    this.purgeExpired();
    const quoteId = randomUUID();
    this.quotes.set(quoteId, {
      quote,
      wallet: user.walletAddress,
      expires: Date.now() + QUOTE_TTL_MS,
      // The build step needs the same fee account the quote was priced with.
      feeAccount: feeBps > 0 ? payToken.feeAccount : '',
    });

    return {
      quoteId,
      payWith: payToken.symbol,
      inputAmount: amount,
      estimatedShares: Number(quote.outAmount) / 10 ** stock.decimals,
      priceImpactPct: Number(quote.priceImpactPct),
      platformFeeBps: feeBps,
      platformFee: (amount * feeBps) / 10_000,
    };
  }

  /** Builds the unsigned swap transaction (base64) for the quoted buy. */
  async build(user: AuthUser, quoteId: string): Promise<{ swapTransaction: string }> {
    const entry = this.quotes.get(quoteId);
    if (!entry || entry.expires < Date.now() || entry.wallet !== user.walletAddress) {
      throw new BadRequestException('Quote expired, request a new one');
    }
    this.quotes.delete(quoteId);

    const res = await fetch(`${this.config.jupiterApiUrl}/swap/v1/swap`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...this.config.jupiterHeaders },
      body: JSON.stringify({
        quoteResponse: entry.quote,
        userPublicKey: user.walletAddress,
        ...(entry.feeAccount ? { feeAccount: entry.feeAccount } : {}),
        dynamicComputeUnitLimit: true,
        prioritizationFeeLamports: 'auto',
      }),
    });
    if (!res.ok) await this.fail(res, 'building the transaction');
    const { swapTransaction } = (await res.json()) as { swapTransaction: string };
    return { swapTransaction };
  }

  /** Waits for the user-sent swap to confirm, then refreshes their balances. */
  async confirm(user: AuthUser, signature: string): Promise<{ confirmed: true }> {
    for (let attempt = 0; attempt < 30; attempt++) {
      const {
        value: [status],
      } = await this.chain.connection.getSignatureStatuses([signature]);
      if (status?.err) {
        throw new BadRequestException('Swap failed on-chain');
      }
      if (status?.confirmationStatus === 'confirmed' || status?.confirmationStatus === 'finalized') {
        this.chain.invalidateBalances(user.walletAddress);
        return { confirmed: true };
      }
      await new Promise((resolve) => setTimeout(resolve, 1_000));
    }
    throw new GatewayTimeoutException('Swap not confirmed yet, check your wallet');
  }

  private purgeExpired() {
    const now = Date.now();
    for (const [id, entry] of this.quotes) {
      if (entry.expires < now) this.quotes.delete(id);
    }
  }
}

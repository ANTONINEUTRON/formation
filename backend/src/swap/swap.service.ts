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
import type { AuthUser, SellQuoteDto, SwapQuoteDto } from '../domain/dto.js';
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
 * Buys an xStock through Jupiter, paying with USDC, SOL or SKR, and sells one
 * for USDC. The backend adds the platform fee and returns an unsigned
 * transaction; the player's wallet signs and sends it, so Formation never has
 * custody of funds.
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
    // Jupiter already rejects anything it cannot route. There is a floor,
    // though — below roughly a dollar the network fee and the rent for a
    // first-time token account both cost more than the trade itself, so the
    // player pays to place a buy that buys nothing worth holding.
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new BadRequestException('Enter an amount greater than zero');
    }
    if (amount < payToken.minAmount) {
      throw new BadRequestException(
        `The smallest buy is ${payToken.minAmount} ${payToken.symbol}`,
      );
    }
    const stock = (await this.xstocks.byMint()).get(mint);
    if (!stock) throw new BadRequestException('Unsupported token');

    const params = new URLSearchParams({
      inputMint: payToken.mint,
      outputMint: mint,
      // Scale by the paying token's own decimals: USDC is 6, SOL is 9.
      amount: String(Math.round(amount * 10 ** payToken.decimals)),
      slippageBps: String(SLIPPAGE_BPS),
      // Every xStock is a Token-2022 mint, and Jupiter's original Route
      // instruction cannot take a platform fee on a Token-2022 swap: it fails
      // on-chain with 6014 IncorrectTokenProgramID before swapping anything.
      // That was every fee-bearing buy, in every pay token — the wallet could
      // not simulate it, and signing anyway just paid the network fee for a
      // failure. V2 is the instruction that supports it.
      instructionVersion: 'V2',
    });
    if (feeBps > 0) params.set('platformFeeBps', String(feeBps));

    const res = await fetch(`${this.config.jupiterApiUrl}/swap/v1/quote?${params}`, {
      headers: this.config.jupiterHeaders,
    });
    if (!res.ok) await this.fail(res, `no route for ${stock.symbol}`);
    const quote = (await res.json()) as JupiterQuote;
    const sellBack = await this.plainQuote(mint, payToken.mint, quote.outAmount);

    return {
      quoteId: this.remember(user, quote, feeBps > 0 ? payToken.feeAccount : ''),
      payWith: payToken.symbol,
      inputAmount: amount,
      estimatedShares: Number(quote.outAmount) / 10 ** stock.decimals,
      priceImpactPct: Number(quote.priceImpactPct),
      platformFeeBps: feeBps,
      platformFee: (amount * feeBps) / 10_000,
      sellBackAmount: sellBack === null ? null : Number(sellBack) / 10 ** payToken.decimals,
    };
  }

  /**
   * Sells held shares for USDC. The same platform fee applies, taken from the
   * USDC received, and the same build and confirm steps follow. Selling a pick
   * that's in the lineup substitutes it off at what it has banked; it's never
   * charged a substitution.
   */
  async quoteSell(user: AuthUser, mint: string, shares: number): Promise<SellQuoteDto> {
    const usdc = this.payToken('USDC');
    const feeBps = this.feeBpsFor(usdc);
    if (!Number.isFinite(shares) || shares <= 0) {
      throw new BadRequestException('Enter an amount greater than zero');
    }
    const stock = (await this.xstocks.byMint()).get(mint);
    if (!stock) throw new BadRequestException('Unsupported token');
    const held = (await this.chain.getBalances(user.walletAddress, { fresh: true })).get(mint) ?? 0;
    // A hair of tolerance: the app sends the balance it was shown, rounded.
    if (shares > held * (1 + 1e-9)) {
      throw new BadRequestException(`You hold ${held} ${stock.symbol}`);
    }

    const raw = BigInt(Math.floor(Math.min(shares, held) * 10 ** stock.decimals));
    const params = new URLSearchParams({
      inputMint: mint,
      outputMint: usdc.mint,
      amount: raw.toString(),
      slippageBps: String(SLIPPAGE_BPS),
      instructionVersion: 'V2',
    });
    if (feeBps > 0) params.set('platformFeeBps', String(feeBps));

    const res = await fetch(`${this.config.jupiterApiUrl}/swap/v1/quote?${params}`, {
      headers: this.config.jupiterHeaders,
    });
    if (!res.ok) await this.fail(res, `no route to sell ${stock.symbol}`);
    const quote = (await res.json()) as JupiterQuote;
    // outAmount is already net of the fee, which Jupiter takes from the output.
    const received = Number(quote.outAmount) / 10 ** usdc.decimals;
    const gross = feeBps > 0 ? received / (1 - feeBps / 10_000) : received;
    const buyBack = await this.plainQuote(usdc.mint, mint, quote.outAmount);

    return {
      quoteId: this.remember(user, quote, feeBps > 0 ? usdc.feeAccount : ''),
      shares: Number(raw) / 10 ** stock.decimals,
      estimatedUsdc: received,
      priceImpactPct: Number(quote.priceImpactPct),
      platformFeeBps: feeBps,
      platformFee: gross - received,
      buyBackShares: buyBack === null ? null : Number(buyBack) / 10 ** stock.decimals,
    };
  }

  /** Stores a quote for the build step; only the wallet that asked can build it. */
  private remember(user: AuthUser, quote: JupiterQuote, feeAccount: string): string {
    this.purgeExpired();
    const quoteId = randomUUID();
    this.quotes.set(quoteId, {
      quote,
      wallet: user.walletAddress,
      expires: Date.now() + QUOTE_TTL_MS,
      // The build step needs the same fee account the quote was priced with.
      feeAccount,
    });
    return quoteId;
  }

  /**
   * A fee-free quote, only to show what the reverse trade would return. Null
   * when it can't be had: the warning is a courtesy, never a reason to fail.
   */
  private async plainQuote(inputMint: string, outputMint: string, amount: string): Promise<bigint | null> {
    try {
      const params = new URLSearchParams({ inputMint, outputMint, amount, slippageBps: String(SLIPPAGE_BPS) });
      const res = await fetch(`${this.config.jupiterApiUrl}/swap/v1/quote?${params}`, {
        headers: this.config.jupiterHeaders,
      });
      if (!res.ok) return null;
      const body = (await res.json()) as { outAmount?: string };
      return body.outAmount ? BigInt(body.outAmount) : null;
    } catch {
      return null;
    }
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
    const built = (await res.json()) as {
      swapTransaction: string;
      // Undocumented in the OpenAPI schema but returned in practice, so it is
      // read defensively rather than destructured as required.
      simulationError?: { error?: string; errorCode?: string } | string | null;
    };

    // Jupiter simulates the swap while building it. If that simulation failed,
    // it still hands back a transaction — and handing that on is how a player
    // ends up staring at "this transaction couldn't be simulated" in their
    // wallet and paying a fee to confirm a swap that was never going to land.
    // Refusing here costs them nothing and tells them why.
    if (built.simulationError) {
      const reason =
        typeof built.simulationError === 'string'
          ? built.simulationError
          : (built.simulationError.error ?? built.simulationError.errorCode ?? 'unknown');
      this.logger.warn(`Jupiter flagged the swap as failing: ${reason}`);
      throw new BadRequestException(
        'That trade would fail right now. The price may have moved, or the pool may be too thin for this size — try a smaller amount or a different stock.',
      );
    }

    return { swapTransaction: built.swapTransaction };
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

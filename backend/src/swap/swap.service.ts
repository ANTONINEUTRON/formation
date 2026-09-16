import {
  BadGatewayException,
  BadRequestException,
  GatewayTimeoutException,
  Inject,
  Injectable,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { ChainService } from '../core/chain.service.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import type { AuthUser, SwapQuoteDto } from '../domain/dto.js';
import { XStocksService } from '../xstocks/xstocks.service.js';

const USDC_MINT = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const QUOTE_TTL_MS = 60_000;
const SLIPPAGE_BPS = 100;

interface JupiterQuote {
  outAmount: string;
  priceImpactPct: string;
  [key: string]: unknown;
}

/**
 * USDC → xStock buys through Jupiter. The backend adds the platform fee and
 * returns an unsigned transaction; the user's wallet signs and sends it, so
 * Formation never has custody of funds.
 */
@Injectable()
export class SwapService {
  private readonly quotes = new Map<
    string,
    { quote: JupiterQuote; wallet: string; expires: number }
  >();

  constructor(
    @Inject(CONFIG) private readonly config: AppConfig,
    private readonly xstocks: XStocksService,
    private readonly chain: ChainService,
  ) {}

  /** Jupiter rejects platformFeeBps without a fee account, so both or neither. */
  private get feeBps(): number {
    return this.config.jupiterFeeAccount ? this.config.platformFeeBps : 0;
  }

  async quote(user: AuthUser, mint: string, usdcAmount: number): Promise<SwapQuoteDto> {
    if (usdcAmount < 1 || usdcAmount > 1_000) {
      throw new BadRequestException('Amount must be between $1 and $1,000');
    }
    const stock = (await this.xstocks.byMint()).get(mint);
    if (!stock) throw new BadRequestException('Unsupported token');

    const params = new URLSearchParams({
      inputMint: USDC_MINT,
      outputMint: mint,
      amount: String(Math.round(usdcAmount * 1e6)),
      slippageBps: String(SLIPPAGE_BPS),
    });
    if (this.feeBps > 0) params.set('platformFeeBps', String(this.feeBps));

    const res = await fetch(`${this.config.jupiterApiUrl}/swap/v1/quote?${params}`);
    if (!res.ok) {
      throw new BadGatewayException(`No Jupiter route for ${stock.symbol}: ${await res.text()}`);
    }
    const quote = (await res.json()) as JupiterQuote;

    this.purgeExpired();
    const quoteId = randomUUID();
    this.quotes.set(quoteId, {
      quote,
      wallet: user.walletAddress,
      expires: Date.now() + QUOTE_TTL_MS,
    });

    return {
      quoteId,
      inputUsdc: usdcAmount,
      estimatedShares: Number(quote.outAmount) / 10 ** stock.decimals,
      priceImpactPct: Number(quote.priceImpactPct),
      platformFeeBps: this.feeBps,
      platformFeeUsdc: (usdcAmount * this.feeBps) / 10_000,
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
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        quoteResponse: entry.quote,
        userPublicKey: user.walletAddress,
        ...(this.feeBps > 0 ? { feeAccount: this.config.jupiterFeeAccount } : {}),
        dynamicComputeUnitLimit: true,
        prioritizationFeeLamports: 'auto',
      }),
    });
    if (!res.ok) {
      throw new BadGatewayException(`Jupiter swap build failed: ${await res.text()}`);
    }
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

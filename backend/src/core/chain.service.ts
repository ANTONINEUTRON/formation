import { Inject, Injectable, Logger } from '@nestjs/common';
import { Connection, PublicKey } from '@solana/web3.js';
import { CONFIG } from './config.js';
import type { AppConfig } from './config.js';

export interface PriceInfo {
  usdPrice: number;
  /** 24h change in percent (1.5 = +1.5%). */
  priceChange24h: number;
}

// xStocks are Token-2022 mints, so balances must be read from both programs.
const TOKEN_PROGRAMS = [
  new PublicKey('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'),
  new PublicKey('TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb'),
];

const BALANCE_TTL_MS = 30_000;
const PRICE_TTL_MS = 30_000;

/** Solana balance reads and Jupiter prices, with short-lived caches. */
@Injectable()
export class ChainService {
  private readonly logger = new Logger(ChainService.name);
  readonly connection: Connection;
  private readonly balances = new Map<
    string,
    { at: number; value: Map<string, number> }
  >();
  private readonly prices = new Map<string, { at: number; value: PriceInfo }>();

  constructor(@Inject(CONFIG) private readonly config: AppConfig) {
    this.connection = new Connection(config.rpcUrl, 'confirmed');
  }

  /** All SPL token balances (UI amounts) held by [wallet], keyed by mint. */
  async getBalances(
    wallet: string,
    { fresh = false } = {},
  ): Promise<Map<string, number>> {
    const cached = this.balances.get(wallet);
    if (!fresh && cached && Date.now() - cached.at < BALANCE_TTL_MS) {
      return cached.value;
    }

    const owner = new PublicKey(wallet);
    const value = new Map<string, number>();
    for (const programId of TOKEN_PROGRAMS) {
      const { value: accounts } =
        await this.connection.getParsedTokenAccountsByOwner(owner, {
          programId,
        });
      for (const { account } of accounts) {
        const info = account.data.parsed?.info as
          | {
              mint: string;
              tokenAmount: { uiAmount: number | null; uiAmountString: string };
            }
          | undefined;
        if (!info) continue;
        const amount =
          info.tokenAmount.uiAmount ?? Number(info.tokenAmount.uiAmountString);
        value.set(info.mint, (value.get(info.mint) ?? 0) + amount);
      }
    }
    this.balances.set(wallet, { at: Date.now(), value });
    return value;
  }

  invalidateBalances(wallet?: string) {
    if (wallet) this.balances.delete(wallet);
    else this.balances.clear();
  }

  /** USD prices from the Jupiter Price API. Mints with no price are omitted. */
  async getPrices(
    mints: string[],
    { fresh = false } = {},
  ): Promise<Map<string, PriceInfo>> {
    const result = new Map<string, PriceInfo>();
    const missing: string[] = [];
    for (const mint of new Set(mints)) {
      const cached = this.prices.get(mint);
      if (!fresh && cached && Date.now() - cached.at < PRICE_TTL_MS) {
        result.set(mint, cached.value);
      } else {
        missing.push(mint);
      }
    }

    for (let i = 0; i < missing.length; i += 50) {
      const batch = missing.slice(i, i + 50);
      const url = `${this.config.jupiterApiUrl}/price/v3?ids=${batch.join(',')}`;
      // A price outage must not take down the stock list or the tick: skip
      // the batch and let callers fall back to the last known prices.
      let res: Response;
      try {
        res = await fetch(url, { headers: this.config.jupiterHeaders });
      } catch (e) {
        this.logger.warn(`Price request failed: ${String(e)}`);
        continue;
      }
      if (!res.ok) {
        this.logger.warn(`Price request failed: ${res.status}`);
        continue;
      }
      const body = (await res.json()) as Record<
        string,
        { usdPrice?: number; priceChange24h?: number } | null
      >;
      for (const mint of batch) {
        const entry = body[mint];
        if (!entry?.usdPrice) continue;
        const value = {
          usdPrice: entry.usdPrice,
          priceChange24h: entry.priceChange24h ?? 0,
        };
        this.prices.set(mint, { at: Date.now(), value });
        result.set(mint, value);
      }
    }
    return result;
  }
}

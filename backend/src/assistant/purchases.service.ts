import {
  BadGatewayException,
  BadRequestException,
  ConflictException,
  GatewayTimeoutException,
  Inject,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { PRICE_SOURCE } from '../core/sources.js';
import type { PriceSource } from '../core/sources.js';
import type { AuthUser } from '../domain/dto.js';
import type { PayToken } from '../domain/pay-tokens.js';
import { requireString } from '../domain/validate.js';
import { CreditsService } from './credits.service.js';
import type { CreditPack } from './packs.js';
import { MEMO_PREFIX, SKR_PAYMENTS, paymentProblem } from './skr-payments.js';
import type { SkrPayments } from './skr-payments.js';

/** Long enough to open a wallet and approve; short enough that the price holds. */
const QUOTE_TTL_MS = 120_000;
/** A payment may land this long after its quote expired and still count. */
const LANDING_GRACE_S = 300;
const CONFIRM_ATTEMPTS = 20;
const CONFIRM_INTERVAL_MS = 1_000;

export interface CreditQuoteDto {
  quoteId: string;
  packId: string;
  credits: number;
  usd: number;
  /** In whole SKR, for display. */
  skrAmount: number;
  expiresAt: string;
}

/**
 * Selling Assistant Manager credits for SKR.
 *
 * The Manager's wallet signs and sends the transfer; Formation never holds a
 * key. Credits are granted only once the transfer has been read back from the
 * chain and checked against the quote, and a purchase is keyed by its
 * signature so the same transfer can never be counted twice.
 */
@Injectable()
export class PurchasesService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
    @Inject(SKR_PAYMENTS) private readonly payments: SkrPayments,
    private readonly credits: CreditsService,
  ) {}

  /** SKR, if it is configured and there is somewhere to pay it. */
  private get skr(): PayToken | null {
    const token = this.config.payTokens.find((t) => t.symbol === 'SKR');
    return token && this.config.assistantTreasury ? token : null;
  }

  get enabled(): boolean {
    return this.skr !== null;
  }

  get packs(): CreditPack[] {
    return this.config.assistantPacks;
  }

  async quote(user: AuthUser, packId: unknown): Promise<CreditQuoteDto> {
    const skr = this.requireSkr();
    const pack = this.packs.find((p) => p.id === requireString(packId, 'packId'));
    if (!pack) throw new BadRequestException('Unknown credit pack');

    const price = (await this.prices.getPrices([skr.mint], { fresh: true })).get(skr.mint)?.usdPrice ?? 0;
    if (!(price > 0)) throw new BadGatewayException("Couldn't price SKR right now. Try again shortly.");
    const raw = BigInt(Math.ceil((pack.usd / price) * 10 ** skr.decimals));

    const quote = await this.db
      .insertInto('credit_quotes')
      .values({
        user_id: user.id,
        pack_id: pack.id,
        credits: pack.credits,
        usd: pack.usd,
        skr_raw: Number(raw),
        expires_at: new Date(this.clock.now() + QUOTE_TTL_MS),
      })
      .returning(['id', 'expires_at'])
      .executeTakeFirstOrThrow();

    return {
      quoteId: quote.id,
      packId: pack.id,
      credits: pack.credits,
      usd: pack.usd,
      skrAmount: Number(raw) / 10 ** skr.decimals,
      expiresAt: new Date(quote.expires_at).toISOString(),
    };
  }

  /** The unsigned SKR transfer for [quoteId], for the Manager's wallet to sign. */
  async build(user: AuthUser, quoteId: unknown): Promise<{ transaction: string }> {
    const skr = this.requireSkr();
    const quote = await this.openQuote(user, requireString(quoteId, 'quoteId'));
    if (new Date(quote.expires_at).getTime() < this.clock.now()) {
      throw new BadRequestException('That price expired. Get a new quote.');
    }
    const transaction = await this.payments.buildTransfer({
      payer: user.walletAddress,
      mint: skr.mint,
      decimals: skr.decimals,
      treasury: this.config.assistantTreasury,
      amountRaw: BigInt(quote.skr_raw),
      memo: `${MEMO_PREFIX}${quote.id}`,
    });
    return { transaction };
  }

  /**
   * Waits for the transfer to confirm, checks it pays for the quote, and only
   * then adds the credits. Returns the new balance.
   */
  async confirm(user: AuthUser, body: { quoteId?: unknown; signature?: unknown }): Promise<{ credits: number }> {
    const skr = this.requireSkr();
    const signature = requireString(body.signature, 'signature');
    const quote = await this.openQuote(user, requireString(body.quoteId, 'quoteId'));

    let observed = null;
    for (let attempt = 0; attempt < CONFIRM_ATTEMPTS && !observed; attempt++) {
      observed = await this.payments.observe(signature);
      if (!observed) await new Promise((resolve) => setTimeout(resolve, CONFIRM_INTERVAL_MS));
    }
    if (!observed) {
      throw new GatewayTimeoutException(
        "Your payment hasn't confirmed yet. Your credits will appear once it does — try again in a minute.",
      );
    }

    const problem = paymentProblem(observed, {
      payer: user.walletAddress,
      mint: skr.mint,
      treasury: this.config.assistantTreasury,
      amountRaw: BigInt(quote.skr_raw),
      memo: `${MEMO_PREFIX}${quote.id}`,
      notAfter: Math.floor(new Date(quote.expires_at).getTime() / 1000) + LANDING_GRACE_S,
    });
    if (problem) throw new BadRequestException(problem);

    return this.db.transaction().execute(async (trx) => {
      const claimed = await trx
        .updateTable('credit_quotes')
        .set({ used_at: this.clock.date() })
        .where('id', '=', quote.id)
        .where('used_at', 'is', null)
        .returning('id')
        .executeTakeFirst();
      if (!claimed) throw new ConflictException('That purchase was already counted');

      const inserted = await trx
        .insertInto('credit_purchases')
        .values({
          signature,
          user_id: user.id,
          quote_id: quote.id,
          credits: quote.credits,
          skr_raw: quote.skr_raw,
          usd: quote.usd,
        })
        .onConflict((oc) => oc.column('signature').doNothing())
        .returning('signature')
        .executeTakeFirst();
      if (!inserted) throw new ConflictException('That payment was already counted');

      return { credits: await this.credits.addPurchased(trx, user.id, quote.credits, signature) };
    });
  }

  private requireSkr(): PayToken {
    const skr = this.skr;
    if (!skr) throw new ServiceUnavailableException('Buying credits is not available yet');
    return skr;
  }

  private async openQuote(user: AuthUser, quoteId: string) {
    const quote = await this.db
      .selectFrom('credit_quotes')
      .selectAll()
      .where('id', '=', quoteId)
      .where('user_id', '=', user.id)
      .executeTakeFirst()
      .catch(() => undefined); // a malformed uuid is just an unknown quote
    if (!quote) throw new BadRequestException('Unknown quote');
    if (quote.used_at) throw new ConflictException('That purchase was already counted');
    return quote;
  }
}

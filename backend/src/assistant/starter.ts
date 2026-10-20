import {
  BadGatewayException,
  BadRequestException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { BALANCE_SOURCE, PRICE_SOURCE } from '../core/sources.js';
import type { BalanceSource, PriceSource } from '../core/sources.js';
import { captaincyRules } from '../domain/captaincy.js';
import type { AuthUser, XStockDto } from '../domain/dto.js';
import { parseFormation } from '../domain/formation.js';
import { counts } from '../domain/holdings.js';
import { DEFAULT_FORMATION, parseSportMode, rosterShape, slotAccepts } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { requireNumber, requireString } from '../domain/validate.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { AvatarService, CUSTOM_ID } from './avatars.js';
import { characterById } from './characters.js';
import { CreditsService } from './credits.service.js';
import type { AdviceStyle } from './characters.js';
import { LLM_PROVIDER, LlmError } from './llm.js';
import type { LlmProvider } from './llm.js';
import { starterPrompt, STARTER_SCHEMA } from './prompt.js';

/** What to report as affordable when drafts are set to cost nothing. */
const STARTER_DRAFTS = 2;
const MAX_BUDGET_USD = 10_000;

export interface StarterPickDto {
  slotIndex: number;
  position: string;
  mint: string;
  symbol: string;
  name: string;
  tier: string;
  priceUsd: number;
  reason: string;
  /** False when the wallet already holds it: no purchase needed. */
  needsPurchase: boolean;
  /** Dollars to spend on it; 0 when already held. */
  amountUsd: number;
}

export interface StarterSquadDto {
  mode: SportMode;
  formation: string | null;
  captainSlot: number | null;
  viceCaptainSlot: number | null;
  picks: StarterPickDto[];
  text: string;
  budgetUsd: number;
  /** SKR's dollar price, so the app can pay in SKR; null when SKR isn't offered. */
  skrUsd: number | null;
  /** Further drafts the credits left after this one pay for. */
  draftsLeft: number;
  /** The credit balance after paying for this draft. */
  credits: number;
}

/**
 * The squad draft: the Assistant Manager drafts a complete, valid lineup for
 * a Manager's budget. The Manager reviews it and confirms; the app then buys
 * what they don't hold and fills the slots. Nothing here moves any money.
 * Each draft costs SQUAD_DRAFT_CREDITS from the Manager's credit balance
 * (the welcome credits cover two), refunded if the draft fails.
 */
@Injectable()
export class StarterService {
  private readonly logger = new Logger(StarterService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(LLM_PROVIDER) private readonly llm: LlmProvider,
    @Inject(BALANCE_SOURCE) private readonly balances: BalanceSource,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
    private readonly xstocks: XStocksService,
    private readonly credits: CreditsService,
  ) {}

  /** Squad drafts a credit balance pays for. */
  draftsFor(credits: number): number {
    const cost = this.config.squadDraftCredits;
    return cost > 0 ? Math.floor(credits / cost) : STARTER_DRAFTS;
  }

  /**
   * "I'll build it myself". Kept for app versions that still call it; drafts
   * are paid from credits now, so declining gives nothing up.
   */
  async dismiss(user: AuthUser): Promise<{ draftsLeft: number }> {
    return { draftsLeft: this.draftsFor(await this.credits.balance(user.id)) };
  }

  async draft(user: AuthUser, body: unknown): Promise<StarterSquadDto> {
    const input = (body ?? {}) as Record<string, unknown>;
    const mode = parseSportMode(requireString(input.mode, 'mode'));
    const budgetUsd = requireNumber(input.budgetUsd, 'budgetUsd');
    const style = (['safe', 'balanced', 'bold'] as const).find((s) => s === input.style);
    const slotCount = rosterShape(mode, mode === 'football' ? DEFAULT_FORMATION : null).length;
    const minimum = slotCount * this.minBuyUsd;
    if (!(budgetUsd >= minimum) || budgetUsd > MAX_BUDGET_USD) {
      throw new BadRequestException(
        `A ${mode.replace('_', ' ')} squad needs a budget of at least $${minimum} ($${this.minBuyUsd} a player)`,
      );
    }
    if (!this.llm.available) throw new ServiceUnavailableException('Your Assistant Manager is off duty right now');

    // Paid up front from the one credit balance, and refunded if it fails.
    const cost = this.config.squadDraftCredits;
    const balance = await this.credits.charge(user.id, cost, 'squad_draft');
    if (balance === null) {
      throw new HttpException(`A squad draft costs ${cost} credits`, HttpStatus.PAYMENT_REQUIRED);
    }

    try {
      return await this.build(user, mode, budgetUsd, style, balance);
    } catch (e) {
      await this.credits.refund(user.id, cost, 'squad_draft');
      if (e instanceof LlmError) {
        this.logger.warn(`Squad draft failed: ${e.message}`);
        throw new BadGatewayException(
          "Your Assistant Manager couldn't draft a squad just now. Your credits were refunded.",
        );
      }
      throw e;
    }
  }

  private get minBuyUsd(): number {
    return this.config.payTokens.find((t) => t.symbol === 'USDC')?.minAmount ?? 1;
  }

  private async build(
    user: AuthUser,
    mode: SportMode,
    budgetUsd: number,
    requestedStyle: AdviceStyle | undefined,
    credits: number,
  ): Promise<StarterSquadDto> {
    const [stocks, held, profile] = await Promise.all([
      this.xstocks.list(),
      this.balances.getBalances(user.walletAddress),
      this.db
        .selectFrom('assistant_profiles')
        .select(['character_id', 'personality', 'custom_name'])
        .where('user_id', '=', user.id)
        .executeTakeFirst(),
    ]);
    const character =
      profile?.character_id === CUSTOM_ID
        ? AvatarService.customCharacter(profile.personality, profile.custom_name)
        : (characterById(profile?.character_id) ?? characterById('mentor')!);
    const style = requestedStyle ?? character.style;
    // Dust doesn't count as held: a stock worth under the minimum gets bought.
    const priceOf = new Map(stocks.map((s) => [s.mint, s.priceUsd]));
    const isHeld = (mint: string) => counts(held.get(mint) ?? 0, priceOf.get(mint), this.config.minHoldingUsd);
    const catalogue = stocks.filter((s) => s.priceUsd > 0 && s.mint !== this.config.benchmarkMint);

    const reply = await this.llm.generate({
      system: starterPrompt(character, style, {
        sport: mode,
        budgetUsd,
        positions: mode === 'football' ? 'pick a formation first, then fill its shape' : rosterShape(mode),
        catalogue: catalogue.map((s) => ({
          symbol: s.symbol,
          name: s.companyName,
          tier: s.tier,
          priceUsd: s.priceUsd,
          change24hPct: s.change24hPct,
          held: isHeld(s.mint) || undefined,
        })),
      }),
      messages: [{ role: 'user', text: `Draft my starting ${mode.replace('_', ' ')} squad.` }],
      schema: STARTER_SCHEMA,
      maxOutputTokens: 2_048,
    });
    const json = (reply.json ?? {}) as Record<string, unknown>;

    let formation: string | null = null;
    if (mode === 'football') {
      try {
        formation = parseFormation(json.formation);
      } catch {
        formation = DEFAULT_FORMATION;
      }
    }
    const shape = rosterShape(mode, formation);
    const bySymbol = new Map(catalogue.map((s) => [s.symbol.toUpperCase(), s]));
    const chosen = new Map<number, { stock: XStockDto; reason: string }>();
    const used = new Set<string>();

    // Keep every proposed pick that fits its slot's tier and isn't a repeat.
    for (const raw of Array.isArray(json.picks) ? json.picks : []) {
      const pick = (raw ?? {}) as Record<string, unknown>;
      const slotIndex = typeof pick.slotIndex === 'number' ? pick.slotIndex : -1;
      const position = shape[slotIndex];
      const stock = typeof pick.symbol === 'string' ? bySymbol.get(pick.symbol.trim().toUpperCase()) : undefined;
      if (!position || !stock || chosen.has(slotIndex) || used.has(stock.mint)) continue;
      if (!slotAccepts(position, stock.tier)) continue;
      chosen.set(slotIndex, {
        stock,
        reason: typeof pick.reason === 'string' ? pick.reason.trim().slice(0, 160) : '',
      });
      used.add(stock.mint);
    }

    // Fill anything the model missed, so the squad is always complete:
    // stocks already held first, then by the character's leaning.
    shape.forEach((position, slotIndex) => {
      if (chosen.has(slotIndex)) return;
      const candidates = catalogue
        .filter((s) => !used.has(s.mint) && slotAccepts(position, s.tier))
        .sort((a, b) => Number(isHeld(b.mint)) - Number(isHeld(a.mint)) || leaning(style, a, b));
      const stock = candidates[0];
      if (!stock) return;
      chosen.set(slotIndex, { stock, reason: isHeld(stock.mint) ? 'You already hold it.' : `Fits ${position.label}.` });
      used.add(stock.mint);
    });

    const toBuy = [...chosen.values()].filter((c) => !isHeld(c.stock.mint)).length;
    const each = toBuy > 0 ? Math.floor((budgetUsd / toBuy) * 100) / 100 : 0;
    const picks: StarterPickDto[] = [...chosen.entries()]
      .sort(([a], [b]) => a - b)
      .map(([slotIndex, { stock, reason }]) => ({
        slotIndex,
        position: shape[slotIndex].label,
        mint: stock.mint,
        symbol: stock.symbol,
        name: stock.companyName,
        tier: stock.tier,
        priceUsd: stock.priceUsd,
        reason,
        needsPurchase: !isHeld(stock.mint),
        amountUsd: isHeld(stock.mint) ? 0 : each,
      }));

    const rules = captaincyRules(mode);
    const slotOf = (v: unknown) => (typeof v === 'number' && chosen.has(v) ? v : null);
    const captainSlot = rules.captain ? (slotOf(json.captainSlot) ?? picks[0]?.slotIndex ?? null) : null;
    let viceCaptainSlot = rules.vice ? slotOf(json.viceCaptainSlot) : null;
    if (viceCaptainSlot === captainSlot) viceCaptainSlot = null;

    const skr = this.config.payTokens.find((t) => t.symbol === 'SKR');
    const skrUsd = skr ? ((await this.prices.getPrices([skr.mint])).get(skr.mint)?.usdPrice ?? null) : null;

    return {
      mode,
      formation,
      captainSlot,
      viceCaptainSlot,
      picks,
      text: typeof json.text === 'string' && json.text.trim() ? json.text.trim() : 'Here is your starting lineup.',
      budgetUsd,
      skrUsd: skrUsd && skrUsd > 0 ? skrUsd : null,
      draftsLeft: this.draftsFor(credits),
      credits,
    };
  }
}

/** Safe prefers the calmest movers, bold the biggest, balanced whatever's in between. */
function leaning(style: AdviceStyle, a: XStockDto, b: XStockDto): number {
  const calm = Math.abs(a.change24hPct) - Math.abs(b.change24hPct);
  if (style === 'safe') return calm;
  if (style === 'bold') return b.change24hPct - a.change24hPct;
  return a.symbol.localeCompare(b.symbol);
}

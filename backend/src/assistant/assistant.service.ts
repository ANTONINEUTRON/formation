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
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { BALANCE_SOURCE } from '../core/sources.js';
import type { BalanceSource } from '../core/sources.js';
import type { AuthUser, RosterDto } from '../domain/dto.js';
import { sectorLabel, sectorOf } from '../domain/sectors.js';
import { parseSportMode, rosterShape, slotTierLabel } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { requireString } from '../domain/validate.js';
import { RosterService } from '../roster/roster.service.js';
import { FREE_SUBSTITUTIONS_PER_DAY } from '../scoring/engine/score-entry.js';
import { GeneralScoringService } from '../scoring/general-scoring.service.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { CHARACTERS, characterById } from './characters.js';
import type { AssistantCharacter } from './characters.js';
import { AvatarService, CUSTOM_ID } from './avatars.js';
import { CreditsService } from './credits.service.js';
import type { CreditPack } from './packs.js';
import { PurchasesService } from './purchases.service.js';
import { StarterService } from './starter.js';
import { LLM_PROVIDER, LlmError } from './llm.js';
import type { LlmMessage, LlmProvider } from './llm.js';
import { CardsService } from './cards.js';
import type { CardDto } from './cards.js';
import { REPLY_SCHEMA, newsPrompt, systemPrompt } from './prompt.js';
import { validateSuggestions } from './suggestions.js';
import type { RosterFacts, Suggestion } from './suggestions.js';

/** Credits one reply costs. */
const REPLY_COST = 1;
/** Extra credits for live news on a stat board (a search-grounded call). */
const NEWS_COST = 1;
const NEWS_MAX_TOKENS = 300;
/** Extra credits for a generated HTML card. */
const HTML_COST = 1;
const MAX_MESSAGES = 20;
const MAX_MESSAGE_CHARS = 1_000;
// Room for an HTML card when the model writes one.
const MAX_OUTPUT_TOKENS = 8_192;

/** Screens the app can open the assistant from. */
const SCREENS = ['team', 'draft', 'league', 'leagues', 'stock', 'profile', 'manager'] as const;
type Screen = (typeof SCREENS)[number];

export interface AssistantProfileDto {
  /** Null until the Manager picks one; the app asks on first open. */
  characterId: string | null;
  characters: Pick<AssistantCharacter, 'id' | 'name' | 'tagline' | 'style'>[];
  credits: number;
  /** False when no model is configured: the app shows the assistant as unavailable. */
  available: boolean;
  /** Credit packs for sale, and whether buying them (with SKR) is switched on. */
  packs: CreditPack[];
  canBuyCredits: boolean;
  /**
   * Squad drafts the credit balance pays for, capped at 2. Kept for app
   * versions that read it; newer ones use credits and squadDraftCredits.
   */
  starterDraftsLeft: number;
  /** Credits a squad draft costs. */
  squadDraftCredits: number;
  /** When the Manager's custom avatar was drawn (for image caching); null if none. */
  avatarVersion: number | null;
  /** Credits the next custom avatar costs: 0 for the first. */
  avatarCost: number;
}

export interface AssistantReplyDto {
  text: string;
  mood: 'neutral' | 'happy' | 'concerned';
  suggestions: Suggestion[];
  /** Interactive panels, every number filled in from Formation's own data. */
  cards: CardDto[];
  credits: number;
}

interface ChatInput {
  mode: SportMode;
  screen: Screen;
  focusMint: string | null;
  messages: LlmMessage[];
}

@Injectable()
export class AssistantService {
  private readonly logger = new Logger(AssistantService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(LLM_PROVIDER) private readonly llm: LlmProvider,
    @Inject(BALANCE_SOURCE) private readonly balances: BalanceSource,
    private readonly credits: CreditsService,
    private readonly purchases: PurchasesService,
    private readonly cards: CardsService,
    private readonly starter: StarterService,
    private readonly avatars: AvatarService,
    private readonly rosters: RosterService,
    private readonly general: GeneralScoringService,
    private readonly xstocks: XStocksService,
  ) {}

  async profile(user: AuthUser): Promise<AssistantProfileDto> {
    const [row, credits, avatarVersion, avatarCost] = await Promise.all([
      this.db
        .selectFrom('assistant_profiles')
        .select(['character_id', 'personality', 'custom_name'])
        .where('user_id', '=', user.id)
        .executeTakeFirst(),
      this.credits.balance(user.id),
      this.avatars.drawnAt(user.id),
      this.avatars.cost(user.id),
    ]);
    const custom = avatarVersion === null ? null : AvatarService.customCharacter(row?.personality ?? null, row?.custom_name ?? null);
    const characters = [...CHARACTERS, ...(custom ? [custom] : [])];
    return {
      characterId: characters.find((c) => c.id === row?.character_id)?.id ?? null,
      characters: characters.map(({ id, name, tagline, style }) => ({ id, name, tagline, style })),
      credits,
      available: this.llm.available,
      packs: this.purchases.packs,
      canBuyCredits: this.purchases.enabled,
      starterDraftsLeft: Math.min(2, this.starter.draftsFor(credits)),
      squadDraftCredits: this.config.squadDraftCredits,
      avatarVersion,
      avatarCost,
    };
  }

  async setCharacter(user: AuthUser, value: unknown): Promise<AssistantProfileDto> {
    const id = requireString(value, 'characterId');
    const character =
      id === CUSTOM_ID && (await this.avatars.drawnAt(user.id)) !== null ? { id: CUSTOM_ID } : characterById(id);
    if (!character) throw new BadRequestException('Unknown Assistant Manager');
    await this.db
      .insertInto('assistant_profiles')
      .values({ user_id: user.id, character_id: character.id })
      .onConflict((oc) =>
        oc.column('user_id').doUpdateSet({ character_id: character.id, updated_at: this.clock.date() }),
      )
      .execute();
    return this.profile(user);
  }

  /**
   * One reply. The credit is taken before the model is called and given back
   * if the call fails, so a Manager never pays for an error.
   */
  async chat(user: AuthUser, body: unknown): Promise<AssistantReplyDto> {
    const input = parseChat(body);
    const character = await this.characterOf(user.id);
    if (!this.llm.available) {
      throw new ServiceUnavailableException('The Assistant Manager is not available right now');
    }

    const [roster, held, rows, substitutionsToday] = await Promise.all([
      this.rosters.getRoster(user, input.mode),
      this.balances.getBalances(user.walletAddress),
      this.xstocks.rows(),
      this.general.substitutionsToday(user.id, input.mode),
    ]);
    const stocks = await this.xstocks.list();
    const context = buildContext(input, roster, stocks, held, substitutionsToday);

    const balance = await this.credits.charge(user.id, REPLY_COST, 'reply');
    if (balance === null) {
      throw new HttpException('You are out of Assistant Manager credits', HttpStatus.PAYMENT_REQUIRED);
    }

    let reply;
    try {
      reply = await this.llm.generate({
        system: systemPrompt(character, context),
        messages: input.messages,
        schema: REPLY_SCHEMA,
        maxOutputTokens: MAX_OUTPUT_TOKENS,
      });
    } catch (e) {
      await this.credits.refund(user.id, REPLY_COST, 'reply');
      await this.logUsage(user.id, input.mode, 0, 0, 0, false);
      this.logger.warn(`Assistant reply failed: ${e instanceof LlmError ? e.message : String(e)}`);
      throw new BadGatewayException('Your Assistant Manager could not answer. You were not charged.');
    }
    await this.logUsage(user.id, input.mode, REPLY_COST, reply.tokensIn, reply.tokensOut, true);

    const json = (reply.json ?? {}) as Record<string, unknown>;
    const facts: RosterFacts = {
      mode: input.mode,
      formation: roster.formation,
      shape: rosterShape(input.mode, roster.formation),
      slots: new Map(roster.slots.flatMap((s) => (s.stock ? [[s.slotIndex, s.stock.mint]] : []))),
      captainSlot: roster.captainSlot,
      viceCaptainSlot: roster.viceCaptainSlot,
      held: new Map([...held].filter(([, amount]) => amount > 0)),
      catalogue: new Map(
        rows.map((r) => [
          r.symbol.toUpperCase(),
          { mint: r.mint, symbol: r.symbol, tier: r.tier, paused: r.not_scoring !== null },
        ]),
      ),
      substitutionsToday,
    };
    let cards = await this.cards.build(json.cards, { roster, stocks, held });
    let credits = balance;
    // A generated HTML view is a much longer reply: one more credit, or it's dropped.
    if (cards.some((c) => c.type === 'html')) {
      const charged = await this.credits.charge(user.id, HTML_COST, 'html_view');
      if (charged === null) cards = cards.filter((c) => c.type !== 'html');
      else credits = charged;
    }
    credits = await this.addNews(user.id, input.mode, cards, credits);

    return {
      text: typeof json.text === 'string' && json.text.trim() ? json.text.trim() : '…',
      mood: json.mood === 'happy' || json.mood === 'concerned' ? json.mood : 'neutral',
      suggestions: validateSuggestions(json.suggestions, facts),
      cards,
      credits,
    };
  }

  /**
   * Adds the latest news to the first stat board, from a live web search.
   * It costs one more credit, taken only if the Manager has one and refunded
   * if the search fails; without it the card simply has no news line.
   * Returns the balance after.
   */
  private async addNews(userId: string, mode: SportMode, cards: CardDto[], balance: number): Promise<number> {
    const board = cards.find((c) => c.type === 'statBoard');
    if (!board || board.type !== 'statBoard') return balance;
    const charged = await this.credits.charge(userId, NEWS_COST, 'news');
    if (charged === null) return balance;
    try {
      const result = await this.llm.search(newsPrompt(board.name, board.symbol), NEWS_MAX_TOKENS);
      board.news = { summary: result.text, sources: result.sources };
      await this.logUsage(userId, mode, NEWS_COST, result.tokensIn, result.tokensOut, true);
      return charged;
    } catch (e) {
      this.logger.warn(`News search failed: ${e instanceof LlmError ? e.message : String(e)}`);
      await this.logUsage(userId, mode, 0, 0, 0, false);
      return this.credits.refund(userId, NEWS_COST, 'news');
    }
  }

  private async characterOf(userId: string): Promise<AssistantCharacter> {
    const row = await this.db
      .selectFrom('assistant_profiles')
      .select(['character_id', 'personality', 'custom_name'])
      .where('user_id', '=', userId)
      .executeTakeFirst();
    const character =
      row?.character_id === CUSTOM_ID
        ? AvatarService.customCharacter(row.personality, row.custom_name)
        : characterById(row?.character_id);
    if (!character) throw new BadRequestException('Pick your Assistant Manager first');
    return character;
  }

  private async logUsage(
    userId: string,
    mode: SportMode,
    credits: number,
    tokensIn: number,
    tokensOut: number,
    succeeded: boolean,
  ): Promise<void> {
    await this.db
      .insertInto('assistant_usage')
      .values({
        user_id: userId,
        sport_mode: mode,
        credits,
        tokens_in: tokensIn,
        tokens_out: tokensOut,
        succeeded,
      })
      .execute();
  }
}

/** Validates the request body: the context envelope plus the conversation. */
function parseChat(body: unknown): ChatInput {
  const b = (body ?? {}) as Record<string, unknown>;
  const context = (b.context ?? {}) as Record<string, unknown>;
  const mode = parseSportMode(requireString(context.mode, 'context.mode'));
  const screen = (SCREENS as readonly string[]).includes(context.screen as string)
    ? (context.screen as Screen)
    : 'team';
  const focus = (context.focus ?? {}) as Record<string, unknown>;
  const focusMint = typeof focus.mint === 'string' && focus.mint ? focus.mint : null;

  if (!Array.isArray(b.messages) || b.messages.length === 0) {
    throw new BadRequestException('messages must be a non-empty list');
  }
  const messages: LlmMessage[] = b.messages.slice(-MAX_MESSAGES).map((m) => {
    const message = (m ?? {}) as Record<string, unknown>;
    const text = typeof message.text === 'string' ? message.text.trim() : '';
    if (!text) throw new BadRequestException('Every message needs text');
    return {
      role: message.role === 'assistant' ? 'model' : 'user',
      text: text.slice(0, MAX_MESSAGE_CHARS),
    };
  });
  if (messages[messages.length - 1].role !== 'user') {
    throw new BadRequestException('The last message must be from the Manager');
  }
  return { mode, screen, focusMint, messages };
}

/**
 * The live facts the model answers from. Compact on purpose: every field is
 * here because an answer needs it, and every number comes from the database,
 * never from the model.
 */
function buildContext(
  input: ChatInput,
  roster: RosterDto,
  stocks: Awaited<ReturnType<XStocksService['list']>>,
  held: Map<string, number>,
  substitutionsToday: number,
) {
  const scoreBySlot = new Map((roster.session?.slots ?? []).map((s) => [s.slotIndex, s]));
  const pct = (n: number) => Math.round(n * 10_000) / 100;
  const shape = rosterShape(input.mode, roster.formation);

  return {
    sport: input.mode,
    screen: input.screen,
    formation: roster.formation,
    lineup: roster.slots.map((slot) => {
      const score = scoreBySlot.get(slot.slotIndex);
      return {
        slotIndex: slot.slotIndex,
        position: slot.positionLabel,
        requiredTier: shape[slot.slotIndex] ? slotTierLabel(shape[slot.slotIndex]) : 'any',
        armband:
          roster.captainSlot === slot.slotIndex
            ? 'captain'
            : roster.viceCaptainSlot === slot.slotIndex
              ? 'vice-captain'
              : undefined,
        stock: slot.stock
          ? {
              symbol: slot.stock.symbol,
              name: slot.stock.companyName,
              tier: slot.stock.tier,
              priceUsd: slot.stock.priceUsd,
              change24hPct: slot.stock.change24hPct,
              sharesHeld: slot.balance,
              sector: sectorName(slot.stock.symbol),
              notScoring: slot.stock.notScoring ?? undefined,
              sessionAlphaPct: score ? pct(score.alpha) : undefined,
              sessionPoints: score?.total,
            }
          : null,
      };
    }),
    bench: roster.bench.map((b) => ({
      symbol: b.stock.symbol,
      tier: b.stock.tier,
      notScoring: b.stock.notScoring ?? undefined,
      sharesHeld: b.balance,
      eligibleSlots: b.eligibleSlots,
    })),
    points: {
      season: roster.classicPoints,
      rank: roster.classicRank,
      today: roster.session?.points ?? 0,
      entered: roster.session?.entered ?? false,
    },
    substitutions: {
      usedToday: substitutionsToday,
      freeLeft: Math.max(0, FREE_SUBSTITUTIONS_PER_DAY - substitutionsToday),
    },
    focus: input.focusMint
      ? (stocks.find((s) => s.mint === input.focusMint) ?? null)
      : undefined,
    catalogue: stocks.map((s) => ({
      symbol: s.symbol,
      name: s.companyName,
      tier: s.tier,
      priceUsd: s.priceUsd,
      change24hPct: s.change24hPct,
      held: (held.get(s.mint) ?? 0) > 0 || undefined,
      sector: sectorName(s.symbol),
      notScoring: s.notScoring ?? undefined,
    })),
  };
}

function sectorName(symbol: string): string | undefined {
  const sector = sectorOf(symbol);
  return sector ? sectorLabel(sector) : undefined;
}

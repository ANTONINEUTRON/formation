import type { ScoreEvent, SlotScore } from '../scoring/engine/types.js';
import type { PaySymbol } from './pay-tokens.js';
import type { RiskTier, SportMode } from './sport.js';

/** The signed-in player, set on the request by AuthGuard. */
export interface AuthUser {
  id: string;
  walletAddress: string;
}

// Response shapes. Field names are the contract with the Flutter models in
// `app/lib/features/shared/domain/models.dart`.

export interface XStockDto {
  symbol: string;
  companyName: string;
  mint: string;
  tier: RiskTier;
  priceUsd: number;
  /** Percent, e.g. 1.5 = +1.5%. */
  change24hPct: number;
  logoUrl: string | null;
  /**
   * Why it isn't scoring right now, e.g. "thin market"; null when it is. A
   * paused stock can still be bought, sold and placed in a slot; it just banks
   * nothing until it scores again.
   */
  notScoring: string | null;
}

export interface RosterSlotDto {
  slotIndex: number;
  positionLabel: string;
  stock: XStockDto | null;
  balance: number;
}

/**
 * The current session of the always-running general league. Replaces the old
 * gameweek panel: points bank continuously, so there is nothing to wait for.
 */
export interface SessionDto {
  startsAt: string;
  endsAt: string;
  /** True once the player has a complete lineup being scored. */
  entered: boolean;
  /** Points banked since this session opened. */
  points: number;
  slots: SlotScore[];
  teamEvents: ScoreEvent[];
  /** Substitutions made today. */
  substitutionsUsed: number;
  /** Substitutions still free today; beyond this they cost points. */
  freeSubstitutionsLeft: number;
  /** The match week now under way, or whose transfer window is open. */
  matchWeek: MatchWeekDto;
  /** Friday full time to Monday kick-off: substitutions are free and unlimited. */
  transferWindowOpen: boolean;
  /** Today's role events so far: provisional, or disallowed if they fell away. */
  liveEvents: LiveEventDto[];
  /** This week's private-league fixtures, with live scores. */
  liveFixtures: LiveFixtureDto[];
}

export interface MatchWeekDto {
  number: number;
  season: number;
  /** 1–12. */
  weekOfSeason: number;
  kickOff: string;
  fullTime: string;
  nextKickOff: string;
  /** Points this player banked between kick-off and full time. */
  points: number;
  /**
   * True before season 1 kicks off: the pre-season, where points bank but
   * don't count toward any season. The app names it the way each sport does.
   */
  preSeason: boolean;
}

export interface RosterDto {
  mode: SportMode;
  /** Football only, e.g. "4-4-2". */
  formation: string | null;
  captainSlot: number | null;
  viceCaptainSlot: number | null;
  slots: RosterSlotDto[];
  /** Running general-league total, banked on every tick. */
  classicPoints: number;
  classicRank: number | null;
  session: SessionDto | null;
  /** Squad members not in the starting lineup; any of them can be subbed in. */
  bench: BenchSlotDto[];
}

/** A held xStock that isn't in the starting lineup. */
export interface BenchSlotDto {
  stock: XStockDto;
  balance: number;
  /** Slot indexes this stock is eligible for, given its tier. */
  eligibleSlots: number[];
}

export interface FormationChangeDto {
  roster: RosterDto;
  /** Picks that no longer fit the new shape; still owned, just off the team. */
  dropped: XStockDto[];
}

export interface LeaderboardEntryDto {
  rank: number;
  userId: string;
  username: string;
  walletAddress: string;
  /** Running total for the selected period. */
  points: number;
  /** Points banked so far today, shown as the movement figure. */
  todayPoints: number;
  streak: number;
  isCurrentUser: boolean;
  /** Skill rating (0–100), or null before their first full match week. */
  skill: number | null;
}

export interface SwapQuoteDto {
  quoteId: string;
  /** Which token the player is spending. */
  payWith: PaySymbol;
  /** Amount of that token, in its own units. */
  inputAmount: number;
  estimatedShares: number;
  priceImpactPct: number;
  /** 0 when the paying token has no fee account configured. */
  platformFeeBps: number;
  /** The fee, in the paying token. */
  platformFee: number;
  /**
   * What selling the shares straight back would return, in the paying token;
   * null when it couldn't be quoted. Far below [inputAmount] means a thin
   * market, and the app says so before the Manager signs.
   */
  sellBackAmount: number | null;
}

/** Selling held shares for USDC. */
export interface SellQuoteDto {
  quoteId: string;
  shares: number;
  /** USDC received, after the fee. */
  estimatedUsdc: number;
  priceImpactPct: number;
  platformFeeBps: number;
  /** The fee, in USDC. */
  platformFee: number;
  /**
   * Shares that USDC would buy straight back; null when it couldn't be quoted.
   * Far below [shares] means a thin market.
   */
  buyBackShares: number | null;
}

/** A token the server will accept as payment, for the app's picker. */
export interface PayTokenDto {
  symbol: PaySymbol;
  mint: string;
  decimals: number;
  /** Smallest buy this token will quote, in whole units of the token. */
  minAmount: number;
}

/**
 * A custom league. A PvP duel is the same object with `maxMembers: 2` and
 * private visibility, so both share one lifecycle: the creator sets the start
 * and the duration, lineups lock when it opens, and it settles when it ends.
 */
export interface LeagueDto {
  id: string;
  name: string;
  mode: SportMode;
  visibility: 'public' | 'private';
  /** Shareable code; private leagues need it to join. */
  joinCode: string;
  startsAt: string;
  endsAt: string;
  status: 'scheduled' | 'live' | 'final';
  maxMembers: number | null;
  memberCount: number;
  createdBy: string;
  /** True when the signed-in player is a member. */
  joined: boolean;
  /** True while the league is still open to join. */
  joinable: boolean;
  /** Ranked once the league is live; empty while it is scheduled. */
  standings: LeagueStandingDto[];
  /**
   * Head-to-head fixtures, one round robin round per match week inside the
   * league. Empty for duels and for leagues shorter than a match week.
   */
  fixtures: FixtureDto[];
  /** W/D/L table from finished fixtures; empty when there are none. */
  table: LeagueTableRowDto[];
}

export interface FixtureDto {
  week: number;
  weekOfSeason: number;
  kickOff: string;
  fullTime: string;
  homeId: string;
  homeName: string;
  /** Null is a bye. */
  awayId: string | null;
  awayName: string | null;
  /** Null until full time. */
  homePoints: number | null;
  awayPoints: number | null;
  status: 'scheduled' | 'final';
}

export interface LeagueTableRowDto {
  rank: number;
  userId: string;
  username: string;
  played: number;
  won: number;
  drawn: number;
  lost: number;
  pointsFor: number;
  pointsAgainst: number;
  /** 3 a win, 1 a draw. */
  tablePoints: number;
  /** Last five results, oldest first. */
  form: ('W' | 'D' | 'L')[];
}

/**
 * The Assistant Manager's weekly portfolio health card: balance, framed as
 * football. Never "profit": beat the market, balance your team, stay
 * consistent.
 */
export interface PortfolioHealthDto {
  mode: SportMode;
  week: number;
  weekOfSeason: number;
  season: number;
  /** Points banked this match week. */
  points: number;
  tiers: { tier: RiskTier; count: number }[];
  /** Share of the team's value in each sector, biggest first. */
  sectors: { sector: string; label: string; sharePct: number }[];
  /** The team balance bonus: how many sectors, how many it takes. */
  balance: { sectors: number; needed: number; bonus: number; earned: boolean };
  carried: { symbol: string; points: number } | null;
  dragged: { symbol: string; points: number } | null;
  /** Plain-language takeaways. */
  lessons: string[];
}

/** A player's push settings. */
export interface PushSettingsDto {
  /** False when the server has no FCM credentials: nothing is pushed. */
  available: boolean;
  /** Devices registered for this player. */
  devices: number;
  /** match_week, goals, not_scoring, season, points, leagues, social. */
  categories: Record<string, boolean>;
  quietEnabled: boolean;
  /** Minutes after local midnight. */
  quietStart: number;
  quietEnd: number;
  timeZone: string;
  /** Most pushes in any 24 hours; the in-app inbox still gets everything. */
  dailyBudget: number;
}

/** Skill, made visible: on profiles and the Skill board. */
export interface SkillDto {
  /** 0–100; 50 matches the market. Risk-adjusted, so steady beats lucky. */
  rating: number;
  weeks: number;
  /** True once there are enough weeks to appear on the Skill board. */
  ranked: boolean;
  /** "Beats the market by +2.1% a week on average." */
  alphaPerWeekPct: number;
  /** Share of picks that beat the S&P 500 over their week. */
  hitRatePct: number;
  /** Share of weeks the captain outscored the team's average pick. */
  shrewdCaptainPct: number | null;
  /** Last five weeks against the market, oldest first. */
  form: ('W' | 'D' | 'L')[];
}

/** A role event as it happens today: provisional until the daily rollup. */
export interface LiveEventDto {
  slotIndex: number;
  mint: string;
  symbol: string;
  code: string;
  label: string;
  points: number;
  status: 'provisional' | 'confirmed' | 'disallowed';
  at: string;
}

/** A private-league fixture being played this week, with the live score. */
export interface LiveFixtureDto {
  leagueId: string;
  leagueName: string;
  opponent: string | null;
  points: number;
  opponentPoints: number;
  final: boolean;
}

/** A player's match week: the full-time result card. */
export interface MatchWeekResultDto {
  week: MatchWeekDto;
  /** False while the week is still being played. */
  final: boolean;
  points: number;
  /** On this week's board; null if they banked nothing. */
  rank: number | null;
  players: number;
  /** The pick that scored most this week. */
  manOfTheMatch: { symbol: string; points: number } | null;
  /** Goals (or the sport's equivalent), in order; today's are provisional. */
  goals: { at: string; symbol: string; label: string; points: number; provisional?: boolean }[];
  /** The tick that moved the score most. */
  turningPoint: { at: string; points: number } | null;
}

export interface LeagueStandingDto {
  rank: number;
  userId: string;
  username: string;
  walletAddress: string;
  points: number;
  isCurrentUser: boolean;
}

export interface NotificationDto {
  id: string;
  kind:
    | 'points'
    | 'league_started'
    | 'league_settled'
    | 'league_joined'
    | 'new_follower'
    | 'manager_move'
    | 'match_week'
    | 'transfer_window'
    | 'season_final'
    | 'goal'
    | 'not_scoring';
  title: string;
  body: string;
  /** Deep-link payload, e.g. { leagueId }. */
  data: Record<string, unknown> | null;
  read: boolean;
  createdAt: string;
}

/**
 * Another player's public profile.
 *
 * Holdings are readable because a Solana wallet is public; nothing here is
 * private and nothing can be acted on without the viewer's own signature.
 */
export interface ManagerDto {
  userId: string;
  username: string;
  bio: string | null;
  walletAddress: string;
  mode: SportMode;
  rank: number | null;
  points: number;
  todayPoints: number;
  streak: number;
  /** Settled leagues they finished first in, and how many they played. */
  leaguesWon: number;
  leaguesPlayed: number;
  /** Their starting lineup for this sport; empty if they haven't drafted. */
  lineup: RosterSlotDto[];
  /** Football only: the shape [lineup] slot indexes map onto. */
  formation: string | null;
  captainSlot: number | null;
  viceCaptainSlot: number | null;
  /** Every eligible xStock in their wallet, for the adopt sheet. */
  holdings: ManagerHoldingDto[];
  followers: number;
  /** True when the signed-in player follows them. */
  following: boolean;
  isCurrentUser: boolean;
  /** Finished seasons in this sport, newest first. */
  seasons: { season: number; points: number; rank: number; players: number }[];
  /** Every badge they've earned, in any sport. */
  badges: { code: string; label: string; mode: SportMode | null; season: number | null }[];
  /** Null before their first full match week. */
  skill: SkillDto | null;
}

export interface ManagerHoldingDto {
  stock: XStockDto;
  balance: number;
  valueUsd: number;
  /** True when this holding is in their starting lineup. */
  starting: boolean;
}

/**
 * The signed-in player's own profile, the only one they can edit.
 *
 * This is the only shape that carries [email]. ManagerDto deliberately has no
 * email field, so another player's profile cannot leak one even by accident.
 */
export interface ProfileDto {
  userId: string;
  username: string;
  bio: string | null;
  /** Private to this player. */
  email: string | null;
  walletAddress: string;
  followers: number;
  following: number;
}

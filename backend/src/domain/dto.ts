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
}

/** A token the server will accept as payment, for the app's picker. */
export interface PayTokenDto {
  symbol: PaySymbol;
  mint: string;
  decimals: number;
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
    | 'manager_move';
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
  /** Every eligible xStock in their wallet, for the adopt sheet. */
  holdings: ManagerHoldingDto[];
  followers: number;
  /** True when the signed-in player follows them. */
  following: boolean;
  isCurrentUser: boolean;
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

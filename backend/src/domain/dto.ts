import type { EntryBreakdown, ScoreEvent, SlotScore } from '../scoring/engine/types.js';
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

export interface GameweekDto {
  id: string;
  number: number;
  startsAt: string;
  endsAt: string;
  status: 'live' | 'final';
  /** True once this player's lineup is locked into the gameweek. */
  entered: boolean;
  /** Points so far (live) or final points once settled. */
  points: number;
  slots: SlotScore[];
  teamEvents: ScoreEvent[];
}

export interface RosterDto {
  mode: SportMode;
  /** Football only, e.g. "4-4-2". */
  formation: string | null;
  captainSlot: number | null;
  viceCaptainSlot: number | null;
  slots: RosterSlotDto[];
  /** Season total from finalised gameweeks. */
  classicPoints: number;
  classicRank: number | null;
  gameweek: GameweekDto | null;
  /** True when the team has changed since the current gameweek locked. */
  pendingChanges: boolean;
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
  /** Season total plus live gameweek points. */
  points: number;
  gameweekPoints: number;
  streak: number;
  isCurrentUser: boolean;
}

export interface DuelCategoryDto {
  code: string;
  name: string;
  challenger: number;
  opponent: number;
  winner: 'challenger' | 'opponent' | 'tie';
}

export interface DuelDto {
  id: string;
  challenger: LeaderboardEntryDto;
  opponent: LeaderboardEntryDto;
  mode: SportMode;
  durationHours: number;
  status: 'pending' | 'active' | 'settled' | 'declined';
  startTime: string | null;
  endTime: string | null;
  challengerPoints: number | null;
  opponentPoints: number | null;
  /** Basketball duels are decided on categories. */
  categories: DuelCategoryDto[] | null;
  challengerBreakdown: EntryBreakdown | null;
  opponentBreakdown: EntryBreakdown | null;
  winnerId: string | null;
}

export interface TrophyDto {
  id: string;
  title: string;
  mode: SportMode;
  awardedAt: string;
  txSignature: string | null;
}

export interface SwapQuoteDto {
  quoteId: string;
  inputUsdc: number;
  estimatedShares: number;
  priceImpactPct: number;
  platformFeeBps: number;
  platformFeeUsdc: number;
}

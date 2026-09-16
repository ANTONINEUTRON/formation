import type { Lineup } from './lineup.js';
import { RiskTier, SportMode } from './sport.js';

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

export interface RosterDto {
  mode: SportMode;
  slots: RosterSlotDto[];
  lastReturnPct: number;
  classicPoints: number;
  classicRank: number | null;
  lastTickAt: string | null;
  /** Football only; null for other sports. */
  lineup: Lineup | null;
}

export interface LeaderboardEntryDto {
  rank: number;
  userId: string;
  username: string;
  walletAddress: string;
  points: number;
  streak: number;
  isCurrentUser: boolean;
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
  challengerReturnPct: number | null;
  opponentReturnPct: number | null;
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

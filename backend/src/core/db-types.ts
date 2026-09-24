import type { ColumnType, Generated, Insertable, Selectable, Updateable } from 'kysely';
import type { SportMode } from '../domain/sport.js';
import type { EntryBreakdown, LineupSnapshot } from '../scoring/engine/types.js';

type Timestamp = ColumnType<Date, Date | string | undefined, Date | string>;

export interface UsersTable {
  id: Generated<string>;
  wallet_address: string;
  username: string;
  is_seed: Generated<boolean>;
  created_at: Timestamp;
}

export interface XStocksTable {
  mint: string;
  symbol: string;
  company_name: string;
  tier: 'blue_chip' | 'stable' | 'balanced' | 'growth' | 'momentum';
  decimals: Generated<number>;
  logo_url: string | null;
}

export interface RostersTable {
  id: Generated<string>;
  user_id: string;
  sport_mode: SportMode;
  formation: string | null;
  captain_slot: number | null;
  vice_captain_slot: number | null;
  created_at: Timestamp;
}

export interface RosterSlotsTable {
  roster_id: string;
  slot_index: number;
  position_label: string;
  token_mint: string;
}

export interface PriceTicksTable {
  mint: string;
  price_usd: number;
  captured_at: Timestamp;
}

export interface GameweeksTable {
  id: Generated<string>;
  sport_mode: SportMode;
  number: number;
  starts_at: Timestamp;
  ends_at: Timestamp;
  status: Generated<'live' | 'final'>;
  created_at: Timestamp;
}

export interface ScoreEntriesTable {
  context: 'gameweek' | 'duel';
  context_id: string;
  user_id: string;
  sport_mode: SportMode;
  snapshot: ColumnType<LineupSnapshot, LineupSnapshot | string, LineupSnapshot | string>;
  end_balances: ColumnType<
    Record<string, number> | null,
    Record<string, number> | string | null,
    Record<string, number> | string | null
  >;
  live_points: Generated<number>;
  final_points: number | null;
  breakdown: ColumnType<
    EntryBreakdown | null,
    EntryBreakdown | string | null,
    EntryBreakdown | string | null
  >;
  updated_at: Timestamp;
}

export interface ClassicScoresTable {
  user_id: string;
  sport_mode: SportMode;
  total_points: Generated<number>;
  last_gameweek_points: Generated<number>;
  streak: Generated<number>;
  updated_at: Timestamp;
}

export interface DuelsTable {
  id: Generated<string>;
  challenger_id: string;
  opponent_id: string;
  sport_mode: SportMode;
  duration_hours: number;
  status: Generated<'pending' | 'active' | 'settled' | 'declined'>;
  start_time: Timestamp | null;
  end_time: Timestamp | null;
  challenger_points: number | null;
  opponent_points: number | null;
  result: ColumnType<unknown | null, unknown, unknown>;
  winner_id: string | null;
  created_at: Timestamp;
}

export interface TrophiesTable {
  id: Generated<string>;
  user_id: string;
  sport_mode: SportMode;
  type: 'duel_win' | 'classic_milestone';
  title: string;
  duel_id: string | null;
  tx_signature: string | null;
  awarded_at: Timestamp;
}

export interface Database {
  users: UsersTable;
  xstocks: XStocksTable;
  rosters: RostersTable;
  roster_slots: RosterSlotsTable;
  price_ticks: PriceTicksTable;
  gameweeks: GameweeksTable;
  score_entries: ScoreEntriesTable;
  classic_scores: ClassicScoresTable;
  duels: DuelsTable;
  trophies: TrophiesTable;
}

export type User = Selectable<UsersTable>;
export type XStockRow = Selectable<XStocksTable>;
export type Roster = Selectable<RostersTable>;
export type RosterSlot = Selectable<RosterSlotsTable>;
export type Gameweek = Selectable<GameweeksTable>;
export type ScoreEntry = Selectable<ScoreEntriesTable>;
export type ClassicScore = Selectable<ClassicScoresTable>;
export type Duel = Selectable<DuelsTable>;
export type Trophy = Selectable<TrophiesTable>;
export type NewUser = Insertable<UsersTable>;
export type NewDuel = Insertable<DuelsTable>;
export type DuelUpdate = Updateable<DuelsTable>;

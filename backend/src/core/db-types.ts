import type { ColumnType, Generated, Insertable, Selectable } from 'kysely';
import type { SportMode } from '../domain/sport.js';
import type { EntryBreakdown, LineupSnapshot, SlotExits } from '../scoring/engine/types.js';

type Timestamp = ColumnType<Date, Date | string | undefined, Date | string>;

export interface UsersTable {
  id: Generated<string>;
  wallet_address: string;
  username: string;
  /** Short public blurb shown on the player's profile. */
  bio: string | null;
  /** Private. Never exposed through ManagerDto or any public endpoint. */
  email: string | null;
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

export interface ScoreEntriesTable {
  /** Leagues are the only locked context; a PvP duel is a two-player league. */
  context: 'league';
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
  /** Picks sold during the window, keyed by mint, so they score up to the sale. */
  exits: ColumnType<SlotExits, SlotExits | string | undefined, SlotExits | string>;
  updated_at: Timestamp;
}

/**
 * Rolling scoring state for the always-on general league. Re-snapshotted after
 * every bank, so a substitution takes effect from the next tick.
 */
export interface GeneralEntriesTable {
  user_id: string;
  sport_mode: SportMode;
  snapshot: ColumnType<LineupSnapshot, LineupSnapshot | string, LineupSnapshot | string>;
  exits: ColumnType<SlotExits, SlotExits | string | undefined, SlotExits | string>;
  last_banked_at: Timestamp;
  session_snapshot: ColumnType<
    LineupSnapshot | null,
    LineupSnapshot | string | null,
    LineupSnapshot | string | null
  >;
  last_events_at: Timestamp | null;
  last_breakdown: ColumnType<
    EntryBreakdown | null,
    EntryBreakdown | string | null,
    EntryBreakdown | string | null
  >;
  updated_at: Timestamp;
}

/** Every points movement, so any period is a sum over a date range. */
export interface PointsLedgerTable {
  id: Generated<string>;
  user_id: string;
  sport_mode: SportMode;
  kind: 'alpha' | 'events' | 'substitution';
  points: number;
  detail: ColumnType<unknown, unknown, unknown>;
  at: Timestamp;
}

/** Free-substitution allowance, counted per UTC day. */
export interface DailySubstitutionsTable {
  user_id: string;
  sport_mode: SportMode;
  day: ColumnType<Date, Date | string, Date | string>;
  used: Generated<number>;
}

export interface LeaguesTable {
  id: Generated<string>;
  name: string;
  creator_id: string;
  sport_mode: SportMode;
  visibility: 'public' | 'private';
  join_code: string;
  starts_at: Timestamp;
  ends_at: Timestamp;
  status: Generated<'scheduled' | 'live' | 'final'>;
  /** Null means unlimited; a PvP duel sets 2. */
  max_members: number | null;
  created_at: Timestamp;
}

export type NotificationKind =
  | 'points'
  | 'league_started'
  | 'league_settled'
  | 'league_joined'
  | 'new_follower'
  | 'manager_move';

/** A one-way subscription to another player's activity. */
export interface FollowsTable {
  follower_id: string;
  followee_id: string;
  created_at: Timestamp;
}

export interface NotificationsTable {
  id: Generated<string>;
  user_id: string;
  kind: NotificationKind;
  title: string;
  body: string;
  /** Deep-link payload, e.g. { leagueId }. */
  data: ColumnType<unknown, unknown, unknown>;
  read_at: Timestamp | null;
  created_at: Timestamp;
}

export interface LeagueMembersTable {
  league_id: string;
  user_id: string;
  joined_at: Timestamp;
}

export interface ClassicScoresTable {
  user_id: string;
  sport_mode: SportMode;
  /** Running total, banked continuously from points_ledger. */
  total_points: Generated<number>;
  streak: Generated<number>;
  updated_at: Timestamp;
}

export interface Database {
  users: UsersTable;
  xstocks: XStocksTable;
  rosters: RostersTable;
  roster_slots: RosterSlotsTable;
  price_ticks: PriceTicksTable;
  score_entries: ScoreEntriesTable;
  general_entries: GeneralEntriesTable;
  points_ledger: PointsLedgerTable;
  daily_substitutions: DailySubstitutionsTable;
  classic_scores: ClassicScoresTable;
  leagues: LeaguesTable;
  league_members: LeagueMembersTable;
  notifications: NotificationsTable;
  follows: FollowsTable;
}

export type User = Selectable<UsersTable>;
export type XStockRow = Selectable<XStocksTable>;
export type Roster = Selectable<RostersTable>;
export type RosterSlot = Selectable<RosterSlotsTable>;
export type ScoreEntry = Selectable<ScoreEntriesTable>;
export type ClassicScore = Selectable<ClassicScoresTable>;
export type GeneralEntry = Selectable<GeneralEntriesTable>;
export type League = Selectable<LeaguesTable>;
export type LeagueMember = Selectable<LeagueMembersTable>;
export type NotificationRow = Selectable<NotificationsTable>;
export type Follow = Selectable<FollowsTable>;
export type NewUser = Insertable<UsersTable>;

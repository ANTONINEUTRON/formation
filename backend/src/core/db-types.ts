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
  /** Free starter-squad drafts used: two allowed (draft + one regenerate). */
  starter_drafts: Generated<number>;
  created_at: Timestamp;
}

export interface XStocksTable {
  mint: string;
  symbol: string;
  company_name: string;
  tier: 'blue_chip' | 'stable' | 'balanced' | 'growth' | 'momentum';
  decimals: Generated<number>;
  logo_url: string | null;
  /** Decides the benchmark (domain/assets.ts). */
  asset_class: Generated<string>;
  /** Pool depth in USD from the last catalogue refresh; null if unknown. */
  liquidity_usd: number | null;
  /** Overrides the curated sector map (domain/sectors.ts). */
  sector: string | null;
}

/** Whether an asset is scoring right now (scoring/engine/eligibility.ts). */
export interface AssetScoringStatusTable {
  mint: string;
  eligible: boolean;
  reason: string | null;
  since: Timestamp;
  passing_since: Timestamp | null;
  checked_at: Timestamp;
  metrics: ColumnType<unknown, unknown, unknown>;
}

export interface ScoringAnomaliesTable {
  id: Generated<string>;
  mint: string;
  at: Timestamp;
  kind: 'jump' | 'status';
  detail: ColumnType<unknown, unknown, unknown>;
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
  /** Base points each pick (by mint) has banked this session, for the cap. */
  session_base: ColumnType<
    Record<string, number>,
    Record<string, number> | string | undefined,
    Record<string, number> | string
  >;
  updated_at: Timestamp;
}

/** Every points movement, so any period is a sum over a date range. */
export interface PointsLedgerTable {
  id: Generated<string>;
  user_id: string;
  sport_mode: SportMode;
  kind: 'alpha' | 'events' | 'substitution' | 'correction' | 'bonus';
  points: number;
  detail: ColumnType<unknown, unknown, unknown>;
  at: Timestamp;
  /** The season [at] falls in (domain/calendar.ts). */
  season: number | null;
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
  | 'manager_move'
  | 'match_week'
  | 'transfer_window'
  | 'season_final'
  | 'goal'
  | 'not_scoring';

export interface SeasonsTable {
  number: number;
  starts_at: Timestamp;
  ends_at: Timestamp;
  finalized_at: Timestamp | null;
}

export interface MatchWeeksTable {
  number: number;
  kick_off: Timestamp;
  full_time: Timestamp;
  kick_off_sent_at: Timestamp | null;
  half_time_sent_at: Timestamp | null;
  full_time_done_at: Timestamp | null;
  transfer_window_sent_at: Timestamp | null;
}

export interface LiveEventsTable {
  id: Generated<string>;
  user_id: string;
  sport_mode: SportMode;
  session_start: Timestamp;
  slot_index: number;
  mint: string;
  symbol: string;
  code: string;
  label: string;
  points: number;
  status: Generated<'provisional' | 'confirmed' | 'disallowed'>;
  at: Timestamp;
  updated_at: Timestamp;
}

export interface WeeklyStatsTable {
  user_id: string;
  sport_mode: SportMode;
  week: number;
  points: number;
  alpha: number;
  picks: number;
  picks_beating: number;
  goals: Generated<number>;
  clean_sheets: Generated<number>;
  captain_points: number | null;
  average_pick_points: number | null;
}

export interface SkillRatingsTable {
  user_id: string;
  sport_mode: SportMode;
  rating: number;
  weeks: number;
  mean_alpha: number;
  volatility: number;
  hit_rate: number;
  captain_rate: number | null;
  updated_at: Timestamp;
}

export interface DeviceTokensTable {
  token: string;
  user_id: string;
  platform: 'android' | 'ios' | 'web';
  created_at: Timestamp;
  last_seen_at: Timestamp;
}

export interface PushPreferencesTable {
  user_id: string;
  categories: ColumnType<Record<string, boolean>, Record<string, boolean> | string | undefined, Record<string, boolean> | string>;
  quiet_enabled: Generated<boolean>;
  quiet_start: Generated<number>;
  quiet_end: Generated<number>;
  time_zone: Generated<string>;
  updated_at: Timestamp;
}

export interface PushLogTable {
  id: Generated<string>;
  user_id: string;
  kind: string;
  sent_at: Timestamp;
}

export interface SeasonResultsTable {
  season: number;
  user_id: string;
  sport_mode: SportMode;
  points: number;
  rank: number;
  players: number;
}

export interface BadgesTable {
  id: Generated<string>;
  user_id: string;
  code: string;
  label: string;
  sport_mode: SportMode | null;
  season: number | null;
  week: number | null;
  awarded_at: Timestamp;
}

export interface LeagueFixturesTable {
  id: Generated<string>;
  league_id: string;
  week: number;
  kick_off: Timestamp;
  full_time: Timestamp;
  home_id: string;
  away_id: string | null;
  home_points: number | null;
  away_points: number | null;
  status: Generated<'scheduled' | 'final'>;
}

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

export interface AssistantProfilesTable {
  user_id: string;
  /** A preset id, or 'custom' for one drawn from the Manager's photo. */
  character_id: string;
  /** For 'custom': which preset's voice and leaning it borrows. */
  personality: string | null;
  custom_name: string | null;
  free_avatar_used: Generated<boolean>;
  updated_at: Timestamp;
}

export interface AssistantAvatarsTable {
  user_id: string;
  pose: 'neutral' | 'thinking' | 'celebrating' | 'concerned';
  mime: string;
  image: Buffer;
  created_at: Timestamp;
}

export interface AssistantCreditsTable {
  user_id: string;
  balance: Generated<number>;
  trial_granted: Generated<boolean>;
  updated_at: Timestamp;
}

export interface AssistantUsageTable {
  id: Generated<string>;
  user_id: string;
  sport_mode: SportMode;
  credits: number;
  tokens_in: Generated<number>;
  tokens_out: Generated<number>;
  succeeded: boolean;
  created_at: Timestamp;
}

export interface CreditQuotesTable {
  id: Generated<string>;
  user_id: string;
  pack_id: string;
  credits: number;
  usd: number;
  skr_raw: number;
  expires_at: Timestamp;
  used_at: Timestamp | null;
  created_at: Timestamp;
}

export interface CreditPurchasesTable {
  signature: string;
  user_id: string;
  quote_id: string;
  credits: number;
  skr_raw: number;
  usd: number;
  created_at: Timestamp;
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
  assistant_profiles: AssistantProfilesTable;
  assistant_credits: AssistantCreditsTable;
  assistant_usage: AssistantUsageTable;
  credit_quotes: CreditQuotesTable;
  credit_purchases: CreditPurchasesTable;
  assistant_avatars: AssistantAvatarsTable;
  asset_scoring_status: AssetScoringStatusTable;
  scoring_anomalies: ScoringAnomaliesTable;
  seasons: SeasonsTable;
  match_weeks: MatchWeeksTable;
  season_results: SeasonResultsTable;
  badges: BadgesTable;
  league_fixtures: LeagueFixturesTable;
  live_events: LiveEventsTable;
  weekly_stats: WeeklyStatsTable;
  skill_ratings: SkillRatingsTable;
  device_tokens: DeviceTokensTable;
  push_preferences: PushPreferencesTable;
  push_log: PushLogTable;
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

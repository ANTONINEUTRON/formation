-- Seasons and match weeks (SCORING_PLAN.md Phase 2).
--
-- A season is 12 match weeks. classic_scores now holds the current season's
-- total: at the end of a season the standings are frozen into season_results,
-- badges are awarded, and totals restart from zero. A match week (Monday
-- kick-off to Friday full time, in ET) is a window over points_ledger.

create table seasons (
  number int primary key,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  -- Set once its standings are frozen and totals reset.
  finalized_at timestamptz
);

create table season_results (
  season int not null references seasons (number),
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  points numeric(10, 1) not null,
  rank int not null,
  -- How many ranked players there were, for "top 10%".
  players int not null,
  primary key (season, user_id, sport_mode)
);

-- Kept across seasons: shown on profiles.
create table badges (
  id bigserial primary key,
  user_id uuid not null references users (id) on delete cascade,
  -- season_champion, season_top10, golden_boot, clean_sheet_king, shrewd_captain
  code text not null,
  label text not null,
  sport_mode text check (sport_mode in ('football', 'basketball', 'american_football')),
  season int,
  -- Match week the badge was earned in, for weekly badges.
  week int,
  awarded_at timestamptz not null default now(),
  -- Postgres 15+: a missing season or week still counts as a duplicate.
  unique nulls not distinct (user_id, code, sport_mode, season, week)
);
create index badges_user on badges (user_id);

-- What has been announced or settled for each match week, so a restart never
-- repeats a kick-off or a full-time result.
create table match_weeks (
  number int primary key,
  kick_off timestamptz not null,
  full_time timestamptz not null,
  kick_off_sent_at timestamptz,
  half_time_sent_at timestamptz,
  full_time_done_at timestamptz,
  transfer_window_sent_at timestamptz
);

-- Every ledger row knows its season, so career totals and season history are
-- sums rather than reconstructions.
alter table points_ledger add column season int;
update points_ledger set season = 1 where season is null;
create index points_ledger_season on points_ledger (sport_mode, season, user_id);

-- Private leagues play head-to-head fixtures each match week (round robin).
create table league_fixtures (
  id bigserial primary key,
  league_id uuid not null references leagues (id) on delete cascade,
  -- Match week number (calendar), and its window.
  week int not null,
  kick_off timestamptz not null,
  full_time timestamptz not null,
  home_id uuid not null references users (id) on delete cascade,
  -- Null is a bye.
  away_id uuid references users (id) on delete cascade,
  home_points numeric(10, 1),
  away_points numeric(10, 1),
  status text not null default 'scheduled' check (status in ('scheduled', 'final')),
  unique (league_id, week, home_id)
);
create index league_fixtures_due on league_fixtures (status, full_time);

alter table notifications drop constraint if exists notifications_kind_check;
alter table notifications
  add constraint notifications_kind_check
  check (kind in (
    'points',
    'league_started',
    'league_settled',
    'league_joined',
    'new_follower',
    'manager_move',
    'match_week',
    'transfer_window',
    'season_final',
    'goal',
    'not_scoring'
  ));

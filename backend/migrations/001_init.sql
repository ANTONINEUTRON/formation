-- Formation schema. Plain PostgreSQL: runs on local Postgres and on
-- Supabase's Postgres unchanged. Applied by scripts/migrate.ts.
--
-- Scoring model (docs/formation-scoring.md):
--   price_ticks    price history for every xStock, including the benchmark
--   gameweeks      scoring windows per sport
--   score_entries  a player's locked lineup + score for one gameweek or duel

create extension if not exists pgcrypto;

create table users (
  id uuid primary key default gen_random_uuid(),
  wallet_address text not null unique,
  username text not null unique,
  -- Demo users that pre-populate leaderboards; skipped by scoring.
  is_seed boolean not null default false,
  created_at timestamptz not null default now()
);

create table xstocks (
  mint text primary key,
  symbol text not null unique,
  company_name text not null,
  tier text not null check (tier in ('blue_chip', 'stable', 'balanced', 'growth', 'momentum')),
  decimals int not null default 8,
  logo_url text
);

create table rosters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  -- Football only, e.g. '4-4-2'. Decides the slot shape.
  formation text,
  -- Captain scores double (football) or ×1.5 (basketball); vice is football only.
  captain_slot int,
  vice_captain_slot int,
  created_at timestamptz not null default now(),
  unique (user_id, sport_mode)
);

create table roster_slots (
  roster_id uuid not null references rosters (id) on delete cascade,
  slot_index int not null,
  -- Role: GK/DEF/MID/FWD, PG/SG/SF/PF/C, QB/RB/WR/TE/FLEX/K.
  position_label text not null,
  token_mint text not null references xstocks (mint),
  primary key (roster_id, slot_index),
  unique (roster_id, token_mint)
);

-- Price history for scoring windows and session (day) buckets.
create table price_ticks (
  mint text not null references xstocks (mint) on delete cascade,
  price_usd double precision not null,
  captured_at timestamptz not null,
  primary key (mint, captured_at)
);
create index price_ticks_time on price_ticks (captured_at);

create table gameweeks (
  id uuid primary key default gen_random_uuid(),
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  number int not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'live' check (status in ('live', 'final')),
  created_at timestamptz not null default now(),
  unique (sport_mode, starts_at)
);
create index gameweeks_live on gameweeks (sport_mode, status, ends_at);

-- One row per player per scoring context. The snapshot is the lineup locked
-- at the start (slots, roles, balances, prices, captaincy), so later roster
-- changes only apply from the next context.
create table score_entries (
  context text not null check (context in ('gameweek', 'duel')),
  context_id uuid not null,
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  snapshot jsonb not null,
  end_balances jsonb,
  live_points numeric(10, 1) not null default 0,
  final_points numeric(10, 1),
  breakdown jsonb,
  updated_at timestamptz not null default now(),
  primary key (context, context_id, user_id)
);
create index score_entries_user on score_entries (user_id, sport_mode);

create table classic_scores (
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  -- Sum of finalised gameweek scores.
  total_points numeric(10, 1) not null default 0,
  last_gameweek_points numeric(10, 1) not null default 0,
  -- Consecutive duel wins in this mode.
  streak int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, sport_mode)
);
create index classic_scores_board on classic_scores (sport_mode, total_points desc);

create table duels (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references users (id) on delete cascade,
  opponent_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  duration_hours int not null check (duration_hours in (1, 6, 24, 72, 168)),
  status text not null default 'pending' check (status in ('pending', 'active', 'settled', 'declined')),
  start_time timestamptz,
  end_time timestamptz,
  challenger_points numeric(10, 1),
  opponent_points numeric(10, 1),
  -- Basketball category results; null for points duels.
  result jsonb,
  winner_id uuid references users (id),
  created_at timestamptz not null default now(),
  check (challenger_id <> opponent_id)
);
create index duels_due on duels (status, end_time);
create index duels_players on duels (sport_mode, challenger_id, opponent_id);

create table trophies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null,
  type text not null check (type in ('duel_win', 'classic_milestone')),
  title text not null,
  duel_id uuid references duels (id) on delete set null,
  -- Memo transaction anchoring the trophy on-chain; null until sent.
  tx_signature text,
  awarded_at timestamptz not null default now()
);
create index trophies_user on trophies (user_id, awarded_at desc);

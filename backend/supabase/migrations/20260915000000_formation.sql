-- Formation schema (spec §4.2). Apply with the Supabase SQL editor or
-- `supabase db push`. The backend uses the service role key; RLS stays off
-- because the app never talks to Supabase directly.

create extension if not exists pgcrypto;

create table users (
  id uuid primary key default gen_random_uuid(),
  wallet_address text not null unique,
  username text not null unique,
  -- Demo users that pre-populate leaderboards.
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
  last_return_pct double precision not null default 0,
  last_tick_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, sport_mode)
);

create table roster_slots (
  roster_id uuid not null references rosters (id) on delete cascade,
  slot_index int not null,
  position_label text not null,
  token_mint text not null references xstocks (mint),
  primary key (roster_id, slot_index),
  unique (roster_id, token_mint)
);

-- Baseline for the next hourly tick. All rows from one tick share captured_at,
-- which is also written to rosters.last_tick_at.
create table hourly_snapshots (
  id bigserial primary key,
  roster_id uuid not null references rosters (id) on delete cascade,
  token_mint text not null,
  balance double precision not null,
  price_usd double precision not null,
  captured_at timestamptz not null
);
create index hourly_snapshots_roster_time on hourly_snapshots (roster_id, captured_at desc);

create table classic_scores (
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  total_points bigint not null default 0,
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
  challenger_return_pct double precision,
  opponent_return_pct double precision,
  winner_id uuid references users (id),
  created_at timestamptz not null default now(),
  check (challenger_id <> opponent_id)
);
create index duels_due on duels (status, end_time);

create table duel_snapshots (
  id bigserial primary key,
  duel_id uuid not null references duels (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  checkpoint text not null check (checkpoint in ('start', 'end')),
  token_mint text not null,
  balance double precision not null,
  price_usd double precision not null,
  captured_at timestamptz not null default now()
);
create index duel_snapshots_lookup on duel_snapshots (duel_id, user_id, checkpoint);

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

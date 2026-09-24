-- The general league stops waiting for a gameweek to close.
--
-- Base alpha is banked on every price tick; role events are awarded once per
-- session (day), because a "goal" is a 3% move and cannot be judged over a
-- five-minute banking interval. Every movement lands in points_ledger, so any
-- period — all time, month, week, custom — is a sum over a date range.

-- Rolling scoring state per player per sport. The snapshot is re-taken after
-- every bank, which is what makes a substitution take effect from the next tick.
create table general_entries (
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  snapshot jsonb not null,
  -- Picks sold since the snapshot: mint -> { at, price }.
  exits jsonb not null default '{}'::jsonb,
  last_banked_at timestamptz not null default now(),
  -- The lineup as it stood when the current session opened, so daily role
  -- events are judged on the team that started the day.
  session_snapshot jsonb,
  -- Start of the session whose events have already been awarded.
  last_events_at timestamptz,
  -- Most recent per-slot breakdown, so the team screen can show contributions
  -- without recomputing the whole interval on every request.
  last_breakdown jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, sport_mode)
);

-- Every points movement, positive or negative.
create table points_ledger (
  id bigserial primary key,
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  -- alpha: banked every tick. events: daily rollup. substitution: paid sub.
  kind text not null check (kind in ('alpha', 'events', 'substitution')),
  points numeric(10, 1) not null,
  detail jsonb,
  at timestamptz not null default now()
);
create index points_ledger_board on points_ledger (sport_mode, at);
create index points_ledger_user on points_ledger (user_id, sport_mode, at);

-- Substitutions are free up to a daily allowance, then cost points. Transfers
-- (buying and selling) are unlimited and free: they are how the app earns.
create table daily_substitutions (
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  day date not null,
  used int not null default 0,
  primary key (user_id, sport_mode, day)
);

-- Locked contexts (leagues) count their own substitutions; the general league
-- uses daily_substitutions instead.
alter table score_entries drop column if exists transfers_used;

-- Superseded by points_ledger: "recent" points are now a sum over a date range.
alter table classic_scores drop column if exists last_gameweek_points;

-- Live events and visible skill (SCORING_PLAN.md Phase 3).

-- Role events as they happen. On every tick each pick's return since the
-- day's open is checked against the event thresholds and recorded here as
-- provisional. The daily rollup confirms them, or marks them disallowed if
-- the price fell back. Only confirmed events ever reach points_ledger, so no
-- leaderboard counts a provisional point.
create table live_events (
  id bigserial primary key,
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  -- Start of the session (day) the event belongs to.
  session_start timestamptz not null,
  slot_index int not null,
  mint text not null,
  symbol text not null,
  code text not null,
  label text not null,
  points numeric(10, 1) not null,
  status text not null default 'provisional'
    check (status in ('provisional', 'confirmed', 'disallowed')),
  -- When it first fired, and when it last changed (a second goal, say).
  at timestamptz not null,
  updated_at timestamptz not null,
  unique (user_id, sport_mode, session_start, mint, code)
);
create index live_events_session on live_events (user_id, sport_mode, session_start);

-- What each player's match week looked like, worked out at full time from
-- the ledger. Skill is computed from these rows, never from new data.
create table weekly_stats (
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  week int not null,
  points numeric(10, 1) not null,
  -- Average pick's return against its benchmark over the week (0.021 = +2.1%).
  alpha numeric(12, 6) not null,
  picks int not null,
  -- Picks that beat the market this week.
  picks_beating int not null,
  goals int not null default 0,
  clean_sheets int not null default 0,
  -- Captain's points before the multiplier, and the team's per-pick average.
  captain_points numeric(10, 1),
  average_pick_points numeric(10, 1),
  primary key (user_id, sport_mode, week)
);

-- Skill rating: risk-adjusted alpha, mean weekly alpha over its volatility,
-- scaled to 0–100 and shrunk toward the middle until about six weeks exist.
create table skill_ratings (
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  rating numeric(5, 1) not null,
  weeks int not null,
  mean_alpha numeric(12, 6) not null,
  volatility numeric(12, 6) not null,
  hit_rate numeric(6, 4) not null,
  captain_rate numeric(6, 4),
  updated_at timestamptz not null,
  primary key (user_id, sport_mode)
);
create index skill_ratings_board on skill_ratings (sport_mode, rating desc);

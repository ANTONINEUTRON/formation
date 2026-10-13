-- Push notifications through FCM (SCORING_PLAN.md Phase 4).
--
-- Every in-app notification already goes through NotificationsService; FCM
-- is added there, so whatever notifies also pushes, subject to each player's
-- settings, their quiet hours and a daily budget.

-- One row per installed app (or browser) that can receive pushes.
create table device_tokens (
  token text primary key,
  user_id uuid not null references users (id) on delete cascade,
  platform text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index device_tokens_user on device_tokens (user_id);

-- What each player wants pushed, and when not to.
create table push_preferences (
  user_id uuid primary key references users (id) on delete cascade,
  -- Category -> on/off; a missing category is on.
  categories jsonb not null default '{}'::jsonb,
  quiet_enabled boolean not null default true,
  -- Minutes after local midnight, e.g. 22:00 -> 1320.
  quiet_start int not null default 1320,
  quiet_end int not null default 480,
  -- IANA zone, e.g. 'Africa/Lagos', for quiet hours.
  time_zone text not null default 'UTC',
  updated_at timestamptz not null default now()
);

-- Pushes sent, for the daily budget.
create table push_log (
  id bigserial primary key,
  user_id uuid not null references users (id) on delete cascade,
  kind text not null,
  sent_at timestamptz not null default now()
);
create index push_log_user_day on push_log (user_id, sent_at);

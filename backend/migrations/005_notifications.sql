-- In-app notifications.
--
-- Written by the services that already know something happened: the daily
-- events rollup, and a league opening, settling or gaining a member. Per-tick
-- alpha is deliberately not notified — it would fire constantly and teach
-- players to ignore the bell.
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  kind text not null check (kind in ('points', 'league_started', 'league_settled', 'league_joined')),
  title text not null,
  body text not null,
  -- Anything the app needs to deep-link, e.g. { "leagueId": "..." }.
  data jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_inbox on notifications (user_id, created_at desc);
create index notifications_unread on notifications (user_id) where read_at is null;

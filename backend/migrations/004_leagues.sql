-- Custom leagues, public or private, created by players.
--
-- A PvP duel is just a two-player private league, so duels and leagues share
-- one code path: the creator sets a start time and a duration, lineups lock
-- when the window opens, and the league settles when it ends. The general
-- league is unaffected and keeps running continuously.

create table leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  creator_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  visibility text not null default 'public' check (visibility in ('public', 'private')),
  -- Shareable code; private leagues need it to join, public ones may use it too.
  join_code text not null unique,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  -- scheduled: open to join. live: lineups locked. final: settled.
  status text not null default 'scheduled' check (status in ('scheduled', 'live', 'final')),
  -- Null means unlimited; a PvP duel sets 2.
  max_members int,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index leagues_due on leagues (status, starts_at, ends_at);
create index leagues_browse on leagues (sport_mode, visibility, status, starts_at);

create table league_members (
  league_id uuid not null references leagues (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);
create index league_members_user on league_members (user_id);

-- score_entries now also holds locked league lineups.
alter table score_entries drop constraint if exists score_entries_context_check;
alter table score_entries
  add constraint score_entries_context_check
  check (context in ('gameweek', 'duel', 'league'));

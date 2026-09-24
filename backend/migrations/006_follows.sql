-- Following a manager.
--
-- A follow is a one-way subscription to another player's activity: when they
-- change their starting lineup, their followers hear about it. It carries no
-- money and no authority — adopting a wallet is a separate, explicit act that
-- the follower signs themselves.
create table follows (
  follower_id uuid not null references users (id) on delete cascade,
  followee_id uuid not null references users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);
create index follows_followee on follows (followee_id);

-- Two more things worth interrupting someone for.
alter table notifications drop constraint if exists notifications_kind_check;
alter table notifications
  add constraint notifications_kind_check
  check (kind in (
    'points',
    'league_started',
    'league_settled',
    'league_joined',
    'new_follower',
    'manager_move'
  ));

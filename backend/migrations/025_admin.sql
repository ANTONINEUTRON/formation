-- The admin dashboard (ADMIN_PLAN.md): an audit log of every admin change,
-- the columns moderation and account deletion need, and the stored wallet
-- reads behind the holdings monitor.

-- When the Manager last used the app. Touched by authenticated requests at
-- most once an hour (SessionService), and the "active" filter reads it.
alter table users add column last_seen_at timestamptz;
-- Suspension: sign-in is refused, scoring and leaderboards skip them, and
-- their past results stay.
alter table users add column suspended_at timestamptz;
alter table users add column suspended_reason text;
-- Deleted on request: the row stays, anonymised, so past league tables still
-- add up.
alter table users add column deleted_at timestamptz;
create index users_created on users (created_at desc);
create index users_last_seen on users (last_seen_at desc);

-- Every admin write, recorded in the same transaction as the change.
create table admin_actions (
  id uuid primary key default gen_random_uuid(),
  -- The admin's wallet address, or 'key' for the x-admin-key header.
  admin text not null,
  -- e.g. score.correct, user.suspend, credits.grant
  action text not null,
  target_user_id uuid references users (id) on delete set null,
  reason text not null check (length(trim(reason)) >= 5),
  -- Before and after values, amounts. Never personal detail.
  detail jsonb,
  created_at timestamptz not null default now()
);
create index admin_actions_newest on admin_actions (created_at desc);
create index admin_actions_by_target on admin_actions (target_user_id, created_at desc);

-- Credits an admin grants or claws back.
alter table credit_ledger drop constraint credit_ledger_reason_check;
alter table credit_ledger add constraint credit_ledger_reason_check check (reason in (
  'opening', 'welcome', 'purchase', 'reply', 'html_view', 'news', 'squad_draft', 'avatar', 'refund',
  'admin'
));

-- The last read of each Manager's wallet, even when it held nothing, so the
-- snapshot job knows who is due and the dashboard knows how old a value is.
create table wallet_reads (
  user_id uuid primary key references users (id) on delete cascade,
  read_at timestamptz not null,
  -- Sum of usd_value over the wallet's holdings at read time.
  total_usd numeric(16, 2) not null default 0
);
create index wallet_reads_due on wallet_reads (read_at);

-- What that read found: catalogue xStocks only, one row per mint.
create table wallet_holdings (
  user_id uuid not null references users (id) on delete cascade,
  mint text not null,
  amount numeric not null,
  -- Null when Jupiter had no price; counted as $0.
  usd_value numeric(16, 2),
  read_at timestamptz not null,
  primary key (user_id, mint)
);
create index wallet_holdings_mint on wallet_holdings (mint);

-- One row per snapshot run: the trend line, without keeping every holding.
create table platform_snapshots (
  taken_at timestamptz primary key,
  managers int not null,
  wallets_read int not null,
  total_usd numeric(16, 2) not null,
  -- { mint: { amount, usd } }
  by_mint jsonb not null
);

-- RPC calls spent on wallet reads, per UTC day, for the daily budget.
create table rpc_usage (
  day date not null,
  source text not null check (source in ('job', 'manual')),
  calls int not null default 0,
  primary key (day, source)
);

-- Scoring integrity (SCORING_PLAN.md, Phase 1).
--
-- Every listed asset stays visible and tradable; whether it scores is decided
-- from its data on every tick. A broken price banks nothing instead of
-- deciding a team's season.

-- What kind of asset each listing is, which picks its benchmark, and how deep
-- its pool is (the catalogue already fetches it; now it's kept).
alter table xstocks
  add column asset_class text not null default 'us_equity',
  add column liquidity_usd numeric;

-- Whether each asset is scoring right now, and why not.
create table asset_scoring_status (
  mint text primary key references xstocks (mint) on delete cascade,
  eligible boolean not null,
  -- no_price, stale_price, price_not_updating, thin_liquidity, erratic_price, recovering
  reason text,
  -- When eligible last changed.
  since timestamptz not null,
  -- When it started passing every requirement; scores again 24 hours later.
  passing_since timestamptz,
  checked_at timestamptz not null,
  metrics jsonb
);

-- Confirmed jumps and status changes, for audit and for tuning the rules.
create table scoring_anomalies (
  id bigserial primary key,
  mint text not null,
  at timestamptz not null,
  kind text not null check (kind in ('jump', 'status')),
  detail jsonb,
  unique (mint, at, kind)
);
create index scoring_anomalies_at on scoring_anomalies (at);

-- Future fixes to banked points are labelled as such.
alter table points_ledger drop constraint points_ledger_kind_check;
alter table points_ledger
  add constraint points_ledger_kind_check
  check (kind in ('alpha', 'events', 'substitution', 'correction'));

-- Base points each pick (by mint) has banked this session, for the daily cap.
alter table general_entries add column session_base jsonb not null default '{}'::jsonb;

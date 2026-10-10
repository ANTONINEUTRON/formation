-- Buying Assistant Manager credits with SKR.
--
-- A quote fixes the SKR amount for a pack at the price of the moment, so the
-- Manager signs exactly what they were shown. The payment itself is an SKR
-- transfer from their wallet to the treasury, carrying the quote id as a memo.
--
-- Credits are granted only after the transfer is read back from the chain and
-- matches the quote. `signature` is the primary key of a purchase and
-- `quote_id` is unique, so neither a replayed transaction nor a reused quote
-- can be counted twice.
create table credit_quotes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  pack_id text not null,
  credits int not null check (credits > 0),
  usd numeric(10, 2) not null,
  -- In the mint's smallest unit.
  skr_raw bigint not null check (skr_raw > 0),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index credit_quotes_user on credit_quotes (user_id, created_at desc);

create table credit_purchases (
  signature text primary key,
  user_id uuid not null references users (id) on delete cascade,
  quote_id uuid not null unique references credit_quotes (id),
  credits int not null,
  skr_raw bigint not null,
  usd numeric(10, 2) not null,
  created_at timestamptz not null default now()
);

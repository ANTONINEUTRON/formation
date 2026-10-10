-- The Assistant Manager: the coach a Manager picks, the credits they spend
-- on replies, and a log of what each reply cost.
--
-- Credits are charged before the model is called and refunded if the call
-- fails, so the balance is only ever moved inside a transaction with a
-- `balance >= cost` guard. A new Manager is granted the trial allowance once;
-- `trial_granted` stops a deleted-and-recreated row from granting it again.
-- Buying credits with SKR comes later and adds its own tables.
create table assistant_profiles (
  user_id uuid primary key references users (id) on delete cascade,
  -- One of the preset characters (see src/assistant/characters.ts).
  character_id text not null,
  updated_at timestamptz not null default now()
);

create table assistant_credits (
  user_id uuid primary key references users (id) on delete cascade,
  balance int not null default 0 check (balance >= 0),
  trial_granted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table assistant_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  sport_mode text not null check (sport_mode in ('football', 'basketball', 'american_football')),
  credits int not null,
  tokens_in int not null default 0,
  tokens_out int not null default 0,
  -- False when the model call failed and the credits were refunded.
  succeeded boolean not null,
  created_at timestamptz not null default now()
);
create index assistant_usage_user on assistant_usage (user_id, created_at desc);

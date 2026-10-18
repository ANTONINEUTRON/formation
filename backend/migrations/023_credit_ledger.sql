-- One credit balance for everything the Assistant Manager does, and a ledger
-- of every move.
--
-- Squad drafts used to have their own allowance (users.starter_drafts: two
-- free, then credits). They're paid in credits now, and the welcome grant
-- covers two of them. Drafts a Manager hadn't used yet become credits at
-- 3 each, the draft price, so nobody loses anything.
--
-- users.starter_drafts stays until a later migration, so a server still on
-- the old code during a deploy keeps working.

-- A Manager who drafted before ever opening the assistant has no balance row:
-- give them the old welcome (5) plus what's left of their drafts.
insert into assistant_credits (user_id, balance, trial_granted)
select id, 5 + greatest(0, 2 - starter_drafts) * 3, true
from users
where starter_drafts > 0
  and not exists (select 1 from assistant_credits c where c.user_id = users.id);

-- Everyone else with a balance: their unused free drafts, as credits.
update assistant_credits c
set balance = c.balance + greatest(0, 2 - u.starter_drafts) * 3,
    updated_at = now()
from users u
where u.id = c.user_id
  and u.starter_drafts < 2;

-- The drafts are now in the balance; mark them used so old code can't give them twice.
update users set starter_drafts = 2 where starter_drafts < 2;

create table credit_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references users (id) on delete cascade,
  -- Credits added (positive) or taken (negative).
  delta int not null,
  balance_after int not null check (balance_after >= 0),
  reason text not null check (reason in (
    'opening', 'welcome', 'purchase', 'reply', 'html_view', 'news', 'squad_draft', 'avatar', 'refund'
  )),
  -- What it was for: a purchase signature, or what a refund gives back.
  ref text,
  created_at timestamptz not null default now()
);
create index credit_ledger_user on credit_ledger (user_id, id desc);

-- Each balance as it stands, so the ledger adds up from here on.
insert into credit_ledger (user_id, delta, balance_after, reason)
select user_id, balance, balance, 'opening' from assistant_credits;

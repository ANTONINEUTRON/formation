-- Selling a pick mid-window used to void it. It now scores what it earned
-- while held, so swapping out a falling stock is a priced decision rather
-- than a total loss.
--
-- exits:          mint -> { at: epoch ms, price: usd } for picks sold in-window
-- transfers_used: roster changes made during this gameweek (see §transfers)
alter table score_entries
  add column if not exists exits jsonb not null default '{}'::jsonb,
  add column if not exists transfers_used integer not null default 0;

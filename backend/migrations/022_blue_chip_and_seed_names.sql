-- The calm tier is called blue chip, as it was before 020 renamed it stable.
alter table xstocks drop constraint xstocks_tier_check;
update xstocks set tier = 'blue_chip' where tier = 'stable';
alter table xstocks
  add constraint xstocks_tier_check check (tier in ('blue_chip', 'balanced', 'momentum'));

-- Demo players go by their wallet, the way a new player does before picking a
-- name: the first and last four characters ("7xKX_3mNq", defaultUsername in
-- users.service.ts). Skipped where that name is already someone else's.
update users
set username = left(wallet_address, 4) || '_' || right(wallet_address, 4)
where is_seed
  and length(wallet_address) > 10
  and not exists (
    select 1 from users other
    where other.id <> users.id
      and lower(other.username) = lower(left(users.wallet_address, 4) || '_' || right(users.wallet_address, 4))
  );

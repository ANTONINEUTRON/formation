-- Repairs default usernames that the API itself refuses.
--
-- Until now a new player's name was `shortAddress(wallet)` — "ANcA…QAtU" —
-- but PATCH /users/me validates names as [A-Za-z0-9_]{3,20}, and the ellipsis
-- is not in that set. The app pre-fills the name field with the player's
-- current name, so saving anything at all sent the invalid default straight
-- back and the whole request was rejected: nobody holding a default name
-- could set a bio without renaming themselves first, and the error pointed at
-- the name rather than explaining that.
--
-- New rows now get "ANcA_QAtU" (see defaultUsername). This fixes the rows
-- already written, so existing players can save too.
--
-- Only untouched defaults are touched. A name a player actually chose cannot
-- contain the ellipsis, so it cannot match.
update users
set username = replace(username, '…', '_')
where username like '%…%'
  -- Skip the vanishingly unlikely case where the repaired name is already
  -- taken: two wallets would have to share their first and last four
  -- characters. Leaving such a row alone keeps this migration from failing
  -- the unique index and rolling back everyone else's repair.
  and not exists (
    select 1
    from users other
    where other.id <> users.id
      and lower(other.username) = lower(replace(users.username, '…', '_'))
  );

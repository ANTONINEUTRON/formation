-- Point the leaderboard's seed players at seven real wallets that hold xStocks.
--
-- Found on 2026-10-12 from the largest holders of popular xStocks, keeping only
-- ordinary wallets (on-curve system accounts, not pools or programs) and
-- leaving out the institutional ones holding 40+ different xStocks. Their
-- holdings are public on-chain, so a seed's manager profile now shows a real
-- xStocks portfolio. The usernames and season points remain demo values:
-- seeds are excluded from scoring (users.is_seed), and these wallets have not
-- signed up to Formation.
--
-- Run in one transaction. Re-running is safe: it's keyed on usernames.
begin;

-- The four existing seeds keep their names and scores, with real wallets.
update users u set wallet_address = v.wallet
from (values
  ('marcusalpha', '44P5Ct5JkPz76Rs2K6juC65zXMpFRDrHatxcASJ4Dyra'),
  ('tola_longs',  'J2f6waBNipqqn2k6d9uw3bwpbapGr2pLKZd9mDczCgfz'),
  ('vega_nwosu',  '8bfcAwx9dZjLGkHcMtuZwaDthuWaQ7bPFMoZeniCSMLS'),
  ('kofi_beta',   '2w9JH4YtCHqQj7dXVj2VZdjKAtuohzfqKZ6YCBG2Q8R1')
) as v(username, wallet)
where u.username = v.username and u.is_seed;

-- Three more seeds.
insert into users (wallet_address, username, is_seed)
values
  ('AC5RDfQFmDS1deWZos921JfqscXdByf8BKHs5ACWjtW2', 'ada_rotates', true),
  ('BmFdpraQhkiDQE6SnfG5omcA1VwzqfXrwtNYBwWTymy6', 'sam_bluechip', true),
  ('6vQAdafYoNRpCdkX3BNBv3dwAXQUAFCWPBVsUu3mM7pF', 'nneka_index', true)
on conflict (username) do update set wallet_address = excluded.wallet_address, is_seed = true;

-- Season points for the new seeds, in the same range as the existing four.
insert into classic_scores (user_id, sport_mode, total_points)
select u.id, s.sport_mode, s.points
from users u
join (values
  ('ada_rotates',  'football', 212.6), ('ada_rotates',  'basketball', 141.3), ('ada_rotates',  'american_football', 77.9),
  ('sam_bluechip', 'football', 153.0), ('sam_bluechip', 'basketball', 188.4), ('sam_bluechip', 'american_football', 104.5),
  ('nneka_index',  'football', 176.8), ('nneka_index',  'basketball',  96.2), ('nneka_index',  'american_football', 131.7)
) as s(username, sport_mode, points) on s.username = u.username
on conflict (user_id, sport_mode) do nothing;

-- Expect 7 seeds, each with a real wallet and three sport scores.
select u.username, u.wallet_address, count(c.*) as sports
from users u left join classic_scores c on c.user_id = u.id
where u.is_seed group by u.id order by u.username;

commit;

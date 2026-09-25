-- Four demo players so the leaderboards are not empty for the hackathon judges.
--
-- An empty ladder reads as a broken feature rather than a new product, and a
-- judge opening the app has no way to tell the difference. Four is enough to
-- show ranking, points spread and streaks without pretending to be a crowd.
--
-- These are marked is_seed, which scoring skips (`general-scoring.service.ts`
-- filters `users.is_seed = false`), so they never consume a price tick, never
-- hold a roster and never affect a real player's points. They exist only to be
-- listed.
--
-- The wallet addresses are real base58 encodings of sha256 digests: correctly
-- shaped and deterministic, but no private key exists for them, so nobody can
-- ever sign in as one of these accounts.
--
-- This lives in a migration rather than the seed script deliberately: it must
-- be present on the deployed server, and the deploy runs migrations but not the
-- seed. To remove them later, delete the rows where is_seed is true.

insert into users (wallet_address, username, bio, is_seed) values
  ('9brGNyJqA2UFmxTcec7XzZLMMRqvS9XL5NXCqD4ERUS7', 'marcusalpha',
   'Chasing alpha one gameweek at a time. Mostly semiconductors.', true),
  ('9jzZE3mJGMtdtF2s5yfKvefCmRhdzj7NNVd1RY9UngGb', 'vega_nwosu',
   'Bench depth wins leagues. Ask me about my defence.', true),
  ('7wnEE4ZbvieMJn1TmJDjYqZCkN6LK1rcUjEogsNn2ZPq', 'tola_longs',
   'Long only. Long everything. Sleeping through the drawdown.', true),
  ('Ga37XJScN4GSVnLQXgv32vNmfuBJpW2yLEafEzZmZVo', 'kofi_beta',
   'Index and chill, with one momentum pick for the thrill.', true)
on conflict (wallet_address) do update
  set username = excluded.username,
      bio      = excluded.bio,
      is_seed  = excluded.is_seed;

-- A spread across all three sports, so every leaderboard has a ladder rather
-- than one populated mode and two empty ones. Points are deliberately modest:
-- a real player should be able to overtake these within a session or two.
-- Note the column list: `last_gameweek_points` from 001_init is gone, dropped
-- with the rest of the gameweek model when 003 moved to continuous banking.
insert into classic_scores (user_id, sport_mode, total_points, streak)
select u.id, s.sport_mode, s.total_points, s.streak
from (values
  ('marcusalpha', 'football',          287.4, 3),
  ('marcusalpha', 'basketball',        152.0, 0),
  ('marcusalpha', 'american_football', 96.2,  0),
  ('vega_nwosu',  'football',          241.8, 1),
  ('vega_nwosu',  'basketball',        178.5, 2),
  ('vega_nwosu',  'american_football', 61.3,  0),
  ('tola_longs',  'football',          198.2, 0),
  ('tola_longs',  'basketball',        203.9, 1),
  ('tola_longs',  'american_football', 142.6, 4),
  ('kofi_beta',   'football',          164.5, 0),
  ('kofi_beta',   'basketball',        119.7, 2),
  ('kofi_beta',   'american_football', 88.1,  1)
) as s(username, sport_mode, total_points, streak)
join users u on u.username = s.username
on conflict (user_id, sport_mode) do update
  set total_points = excluded.total_points,
      streak       = excluded.streak;

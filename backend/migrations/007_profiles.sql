-- Players get a name and a bio.
--
-- Until now a username was derived from the wallet address ("ANcA…QAtU"), which
-- is unreadable on a leaderboard and impossible to recognise on a manager
-- profile. Both fields are public: they appear wherever the player does.
alter table users add column if not exists bio text;

-- Usernames are already unique, but only exactly. Two people should not be able
-- to take "Marcus" and "marcus".
create unique index if not exists users_username_lower on users (lower(username));

-- Optional, and private. Email is for us to reach the player (receipts, league
-- reminders); it is never returned by any endpoint that describes one player to
-- another. Only /users/me sees it.
alter table users add column if not exists email text;
create unique index if not exists users_email_lower
  on users (lower(email)) where email is not null;

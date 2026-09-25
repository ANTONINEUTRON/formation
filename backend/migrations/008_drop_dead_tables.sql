-- Drops the tables left behind by features that no longer exist.
--
--   gameweeks  scoring windows, replaced by continuous banking (003)
--   duels      folded into leagues, where a duel is a two-player one (004)
--   trophies   moved onto the player's own device
--
-- score_entries rows with context 'gameweek' or 'duel' are orphaned by this,
-- so they go too; every live context is a league.
delete from score_entries where context in ('gameweek', 'duel');

alter table score_entries drop constraint if exists score_entries_context_check;
alter table score_entries
  add constraint score_entries_context_check check (context in ('league'));

-- trophies references duels, so order matters here.
drop table if exists trophies;
drop table if exists duels;
drop table if exists gameweeks;

-- Football becomes an FPL-style 15-player squad with a lineup (formation,
-- bench order, captain / vice-captain). Snapshots record each slot's lineup
-- role so captaincy and auto-subs apply per scoring window.
--
-- Football rosters drafted under the old 11-slot shape don't map onto the
-- new squad; clear them before applying if any exist:
--   delete from rosters where sport_mode = 'football';

alter table rosters add column lineup jsonb;

alter table hourly_snapshots
  -- 0 = substitute, 1 = starter, 2 = captain
  add column weight double precision not null default 1,
  add column role text,
  add column bench_order int,
  add column is_vice boolean not null default false;

alter table duel_snapshots
  add column weight double precision not null default 1,
  add column role text,
  add column bench_order int,
  add column is_vice boolean not null default false;

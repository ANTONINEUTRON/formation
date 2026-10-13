-- The portfolio-building layer (SCORING_PLAN.md Phase 5).

-- A listing's own sector, when the curated map in domain/sectors.ts doesn't
-- cover it (a new asset class brings its own). Null falls back to the map.
alter table xstocks add column sector text;

-- The team balance bonus banks as its own kind, so it's never mistaken for
-- alpha or role events.
alter table points_ledger drop constraint points_ledger_kind_check;
alter table points_ledger
  add constraint points_ledger_kind_check
  check (kind in ('alpha', 'events', 'substitution', 'correction', 'bonus'));

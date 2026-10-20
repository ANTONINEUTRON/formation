-- Every listed stock scores. Paused stocks are gone: no eligibility checks,
-- no hourly market-depth quotes, no "not scoring" notifications.
--
-- The tick guard (a jump over MAX_TICK_MOVE waits a tick and is clamped) and
-- the per-pick caps stay; they're part of scoring, not pausing.
drop table if exists asset_scoring_status;
drop table if exists market_depth;
drop table if exists scoring_anomalies;

-- Pool depth was only read by the pausing checks.
alter table xstocks drop column if exists liquidity_usd;

-- "Your captain isn't scoring" no longer means anything.
delete from notifications where kind = 'not_scoring';
alter table notifications drop constraint if exists notifications_kind_check;
alter table notifications
  add constraint notifications_kind_check
  check (kind in (
    'points',
    'league_started',
    'league_settled',
    'league_joined',
    'new_follower',
    'manager_move',
    'match_week',
    'transfer_window',
    'season_final',
    'goal'
  ));

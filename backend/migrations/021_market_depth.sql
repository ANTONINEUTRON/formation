-- How deep each stock's market is: buy a fixed amount and sell it straight
-- back through Jupiter, and record what the round trip loses. A stock only
-- scores while that loss is small, which makes its price expensive to push
-- around. Null loss means Jupiter found no route at all.
create table market_depth (
  mint text primary key references xstocks (mint),
  round_trip_loss_pct double precision,
  probe_usd double precision not null,
  checked_at timestamptz not null
);

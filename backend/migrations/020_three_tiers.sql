-- Five tiers become three: stable, balanced and momentum. Tiers now come from
-- a formula on each stock's beta and volatility (domain/tiers.ts), run each
-- season by `npm run tiers`; this mapping only bridges until that first run.

alter table xstocks drop constraint xstocks_tier_check;

update xstocks set tier = case tier
  when 'stable' then 'stable'
  when 'blue_chip' then 'balanced'
  when 'balanced' then 'balanced'
  when 'growth' then 'momentum'
  when 'momentum' then 'momentum'
  else tier
end;

alter table xstocks
  add constraint xstocks_tier_check check (tier in ('stable', 'balanced', 'momentum'));

-- 'manual' tiers are set by hand and the formula leaves them alone.
alter table xstocks
  add column tier_source text not null default 'formula'
  check (tier_source in ('formula', 'manual'));

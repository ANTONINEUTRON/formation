-- Backpack Securities' tokenized stocks are listed alongside xStocks.
--
-- The table keeps its name; `issuer` says whose token a row is. xStocks keep
-- their "x" symbols (AAPLx); Backpack's are the plain ticker (AAPL), so the
-- unique symbol still tells them apart.
alter table xstocks
  add column issuer text not null default 'xstocks'
  check (issuer in ('xstocks', 'backpack'));

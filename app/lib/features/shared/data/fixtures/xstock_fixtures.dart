import 'package:formation/features/shared/domain/models.dart';

/// Supported xStocks for fixture mode.
///
/// Mints are mainnet xStock (Token-2022, 8 decimals) mints from Jupiter's
/// token list. Prices are fixture values; the backend serves live ones.
/// Keep symbols, mints and tiers in sync with `backend/src/xstocks/xstocks.seed.ts`.
const xStockFixtures = [
  // Blue chip — anchors (GK, C, QB)
  XStock(symbol: 'AAPLx', companyName: 'Apple', mint: 'XsbEhLAtcf6HdfpFZ5xEMdqW8nfAvcsP5bdudRLJzJp', tier: RiskTier.blueChip, priceUsd: 231.40, change24hPct: 0.6),
  XStock(symbol: 'MSFTx', companyName: 'Microsoft', mint: 'XspzcW1PRtgf6Wj92HCiZdjzKCyFekVD8P5Ueh3dRMX', tier: RiskTier.blueChip, priceUsd: 512.10, change24hPct: 0.3),
  XStock(symbol: 'GOOGLx', companyName: 'Alphabet', mint: 'XsCPL9dNWBMvFtTmwcCA5v3xWPSMEBCszbQdiLLq6aN', tier: RiskTier.blueChip, priceUsd: 204.75, change24hPct: -0.4),
  XStock(symbol: 'AMZNx', companyName: 'Amazon', mint: 'Xs3eBt7uRfJX8QUs4suhyU8p2M6DoUDrJyWBa8LLZsg', tier: RiskTier.blueChip, priceUsd: 228.90, change24hPct: 1.1),
  XStock(symbol: 'SPYx', companyName: 'S&P 500 ETF', mint: 'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W', tier: RiskTier.blueChip, priceUsd: 648.20, change24hPct: 0.2),
  XStock(symbol: 'BRK.Bx', companyName: 'Berkshire Hathaway', mint: 'Xs6B6zawENwAbWVi7w92rjazLuAr5Az59qgWKcNb45x', tier: RiskTier.blueChip, priceUsd: 492.30, change24hPct: -0.1),

  // Stable — defenders, TE, K
  XStock(symbol: 'KOx', companyName: 'Coca-Cola', mint: 'XsaBXg8dU5cPM6ehmVctMkVqoiRG2ZjMo1cyBJ3AykQ', tier: RiskTier.stable, priceUsd: 69.85, change24hPct: 0.1),
  XStock(symbol: 'PGx', companyName: 'Procter & Gamble', mint: 'XsYdjDjNUygZ7yGKfQaB6TxLh2gC6RRjzLtLAGJrhzV', tier: RiskTier.stable, priceUsd: 158.40, change24hPct: -0.2),
  XStock(symbol: 'JNJx', companyName: 'Johnson & Johnson', mint: 'XsGVi5eo1Dh2zUpic4qACcjuWGjNv8GCt3dm5XcX6Dn', tier: RiskTier.stable, priceUsd: 177.60, change24hPct: 0.4),
  XStock(symbol: 'MCDx', companyName: "McDonald's", mint: 'XsqE9cRRpzxcGKDXj1BJ7Xmg4GRhZoyY1KpmGSxAWT2', tier: RiskTier.stable, priceUsd: 304.15, change24hPct: 0.0),
  XStock(symbol: 'WMTx', companyName: 'Walmart', mint: 'Xs151QeqTCiuKtinzfRATnUESM2xTU6V9Wy8Vy538ci', tier: RiskTier.stable, priceUsd: 101.20, change24hPct: 0.5),
  XStock(symbol: 'XOMx', companyName: 'Exxon Mobil', mint: 'XsaHND8sHyfMfsWPj6kSdd5VwvCayZvjYgKmmcNL5qh', tier: RiskTier.stable, priceUsd: 112.35, change24hPct: -0.7),

  // Balanced — midfield, forwards in basketball
  XStock(symbol: 'JPMx', companyName: 'JPMorgan Chase', mint: 'XsMAqkcKsUewDrzVkait4e5u4y8REgtyS7jWgCpLV2C', tier: RiskTier.balanced, priceUsd: 301.50, change24hPct: 0.8),
  XStock(symbol: 'Vx', companyName: 'Visa', mint: 'XsqgsbXwWogGJsNcVZ3TyVouy2MbTkfCFhCGGGcQZ2p', tier: RiskTier.balanced, priceUsd: 348.70, change24hPct: 0.2),
  XStock(symbol: 'MAx', companyName: 'Mastercard', mint: 'XsApJFV9MAktqnAc6jqzsHVujxkGm9xcSUffaBoYLKC', tier: RiskTier.balanced, priceUsd: 589.40, change24hPct: 0.3),
  XStock(symbol: 'LLYx', companyName: 'Eli Lilly', mint: 'Xsnuv4omNoHozR6EEW5mXkw8Nrny5rB3jVfLqi6gKMH', tier: RiskTier.balanced, priceUsd: 812.00, change24hPct: -1.2),
  XStock(symbol: 'UNHx', companyName: 'UnitedHealth', mint: 'XszvaiXGPwvk2nwb3o9C1CX4K6zH8sez11E6uyup6fe', tier: RiskTier.balanced, priceUsd: 318.25, change24hPct: 1.4),
  XStock(symbol: 'ORCLx', companyName: 'Oracle', mint: 'XsjFwUPiLofddX5cWFHW35GCbXcSu1BCUGfxoQAQjeL', tier: RiskTier.balanced, priceUsd: 236.80, change24hPct: 2.1),

  // Growth — guards, running backs
  XStock(symbol: 'NVDAx', companyName: 'NVIDIA', mint: 'Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh', tier: RiskTier.growth, priceUsd: 178.30, change24hPct: 2.4),
  XStock(symbol: 'METAx', companyName: 'Meta Platforms', mint: 'Xsa62P5mvPszXL1krVUnU5ar38bBSVcWAB6fmPCo5Zu', tier: RiskTier.growth, priceUsd: 752.60, change24hPct: 1.7),
  XStock(symbol: 'NFLXx', companyName: 'Netflix', mint: 'XsEH7wWfJJu2ZT3UCFeVfALnVA6CP5ur7Ee11KmzVpL', tier: RiskTier.growth, priceUsd: 1215.40, change24hPct: -0.9),
  XStock(symbol: 'AVGOx', companyName: 'Broadcom', mint: 'XsgSaSvNSqLTtFuyWPBhK9196Xb9Bbdyjj4fH3cPJGo', tier: RiskTier.growth, priceUsd: 334.10, change24hPct: 3.2),
  XStock(symbol: 'AMDx', companyName: 'AMD', mint: 'XsXcJ6GZ9kVnjqGsjBnktRcuwMBmvKWh8S93RefZ1rF', tier: RiskTier.growth, priceUsd: 158.90, change24hPct: -1.8),
  XStock(symbol: 'CRMx', companyName: 'Salesforce', mint: 'XsczbcQ3zfcgAEt9qHQES8pxKAVG5rujPSHQEXi4kaN', tier: RiskTier.growth, priceUsd: 246.30, change24hPct: 0.6),

  // Momentum — strikers, receivers
  XStock(symbol: 'TSLAx', companyName: 'Tesla', mint: 'XsDoVfqeBukxuZHWhdvWHBhgEHjGNst4MLodqsJHzoB', tier: RiskTier.momentum, priceUsd: 395.20, change24hPct: 4.6),
  XStock(symbol: 'COINx', companyName: 'Coinbase', mint: 'Xs7ZdzSHLU9ftNJsii5fCeJhoRWSC32SQGzGQtePxNu', tier: RiskTier.momentum, priceUsd: 318.75, change24hPct: -3.4),
  XStock(symbol: 'MSTRx', companyName: 'Strategy', mint: 'XsP7xzNPvEHS1m6qfanPUGjNmdnmsLKEoNAnHjdxxyZ', tier: RiskTier.momentum, priceUsd: 341.90, change24hPct: 5.1),
  XStock(symbol: 'HOODx', companyName: 'Robinhood', mint: 'XsvNBAYkrDRNhA7wPHQfX3ZUXZyZLdnCQDfHZ56bzpg', tier: RiskTier.momentum, priceUsd: 118.40, change24hPct: 3.8),
  XStock(symbol: 'PLTRx', companyName: 'Palantir', mint: 'XsoBhf2ufR8fTyNSjqfU71DYGaE6Z3SUGAidpzriAA4', tier: RiskTier.momentum, priceUsd: 172.60, change24hPct: 2.9),
  XStock(symbol: 'GMEx', companyName: 'GameStop', mint: 'Xsf9mBktVB9BSU5kf4nHxPq5hCBJ2j2ui3ecFGxPRGc', tier: RiskTier.momentum, priceUsd: 23.15, change24hPct: -6.2),
];

// Roughly half the pool is held so both the "Held" and "Buy" draft paths
// are demoable.
const _heldShares = {
  'AAPLx': 2.5, 'SPYx': 0.8, 'KOx': 6.0, 'PGx': 3.0, 'JNJx': 2.0,
  'WMTx': 5.0, 'JPMx': 1.5, 'Vx': 1.2, 'ORCLx': 2.0, 'NVDAx': 4.0,
  'METAx': 0.6, 'TSLAx': 1.8, 'HOODx': 3.5, 'PLTRx': 2.2, 'COINx': 1.0,
  'MCDx': 4.0, 'MAx': 0.5, 'UNHx': 1.0,
};

/// Fixture wallet holdings (shares), keyed by mint.
final heldBalanceFixtures = {
  for (final s in xStockFixtures)
    if (_heldShares.containsKey(s.symbol)) s.mint: _heldShares[s.symbol]!,
};

const seedUsernames = [
  'diamondhands', 'tickertape', 'bullrunbrenda', 'thetaganger', 'nvda_maxi',
  'dividenddan', 'shortsqueeze', 'solstonks', 'bogleheadbob', 'yolo_yuki',
  'bluechipbea', 'gammaray', 'deepvalue', 'mooncalf', 'rebalancer',
  'candlewick', 'paperhandpat', 'etf_ella', 'momentummo', 'basisbp',
  'greenday', 'redcandle', 'bagholder', 'fomo_fin', 'tapereader',
  'hodlhannah', 'alphaseeker', 'betaboy', 'sharpe_ratio', 'drawdown',
  'openbell', 'closingbell', 'afterhours', 'weekendwarrior', 'xstockjock',
  'jupjumper', 'phantomphil', 'backpackbelle', 'pythpriced', 'blockbroker',
];

import { RiskTier } from '../domain/sport.js';

/**
 * Supported xStocks with tiers. Mints are mainnet xStock (Token-2022,
 * 8 decimals) mints from Jupiter's token list, verified 2026-09-15.
 * Keep in sync with `app/lib/features/shared/data/fixtures/xstock_fixtures.dart`.
 */
export const XSTOCKS_SEED: {
  symbol: string;
  companyName: string;
  mint: string;
  tier: RiskTier;
}[] = [
  // Blue chip: anchors (GK, C, QB)
  { symbol: 'AAPLx', companyName: 'Apple', mint: 'XsbEhLAtcf6HdfpFZ5xEMdqW8nfAvcsP5bdudRLJzJp', tier: 'blue_chip' },
  { symbol: 'MSFTx', companyName: 'Microsoft', mint: 'XspzcW1PRtgf6Wj92HCiZdjzKCyFekVD8P5Ueh3dRMX', tier: 'blue_chip' },
  { symbol: 'GOOGLx', companyName: 'Alphabet', mint: 'XsCPL9dNWBMvFtTmwcCA5v3xWPSMEBCszbQdiLLq6aN', tier: 'blue_chip' },
  { symbol: 'AMZNx', companyName: 'Amazon', mint: 'Xs3eBt7uRfJX8QUs4suhyU8p2M6DoUDrJyWBa8LLZsg', tier: 'blue_chip' },
  { symbol: 'SPYx', companyName: 'S&P 500 ETF', mint: 'XsoCS1TfEyfFhfvj8EtZ528L3CaKBDBRqRapnBbDF2W', tier: 'blue_chip' },
  { symbol: 'BRK.Bx', companyName: 'Berkshire Hathaway', mint: 'Xs6B6zawENwAbWVi7w92rjazLuAr5Az59qgWKcNb45x', tier: 'blue_chip' },

  // Stable: defenders, TE, K
  { symbol: 'KOx', companyName: 'Coca-Cola', mint: 'XsaBXg8dU5cPM6ehmVctMkVqoiRG2ZjMo1cyBJ3AykQ', tier: 'stable' },
  { symbol: 'PGx', companyName: 'Procter & Gamble', mint: 'XsYdjDjNUygZ7yGKfQaB6TxLh2gC6RRjzLtLAGJrhzV', tier: 'stable' },
  { symbol: 'JNJx', companyName: 'Johnson & Johnson', mint: 'XsGVi5eo1Dh2zUpic4qACcjuWGjNv8GCt3dm5XcX6Dn', tier: 'stable' },
  { symbol: 'MCDx', companyName: "McDonald's", mint: 'XsqE9cRRpzxcGKDXj1BJ7Xmg4GRhZoyY1KpmGSxAWT2', tier: 'stable' },
  { symbol: 'WMTx', companyName: 'Walmart', mint: 'Xs151QeqTCiuKtinzfRATnUESM2xTU6V9Wy8Vy538ci', tier: 'stable' },
  { symbol: 'XOMx', companyName: 'Exxon Mobil', mint: 'XsaHND8sHyfMfsWPj6kSdd5VwvCayZvjYgKmmcNL5qh', tier: 'stable' },

  // Balanced: midfield, basketball forwards
  { symbol: 'JPMx', companyName: 'JPMorgan Chase', mint: 'XsMAqkcKsUewDrzVkait4e5u4y8REgtyS7jWgCpLV2C', tier: 'balanced' },
  { symbol: 'Vx', companyName: 'Visa', mint: 'XsqgsbXwWogGJsNcVZ3TyVouy2MbTkfCFhCGGGcQZ2p', tier: 'balanced' },
  { symbol: 'MAx', companyName: 'Mastercard', mint: 'XsApJFV9MAktqnAc6jqzsHVujxkGm9xcSUffaBoYLKC', tier: 'balanced' },
  { symbol: 'LLYx', companyName: 'Eli Lilly', mint: 'Xsnuv4omNoHozR6EEW5mXkw8Nrny5rB3jVfLqi6gKMH', tier: 'balanced' },
  { symbol: 'UNHx', companyName: 'UnitedHealth', mint: 'XszvaiXGPwvk2nwb3o9C1CX4K6zH8sez11E6uyup6fe', tier: 'balanced' },
  { symbol: 'ORCLx', companyName: 'Oracle', mint: 'XsjFwUPiLofddX5cWFHW35GCbXcSu1BCUGfxoQAQjeL', tier: 'balanced' },

  // Growth: guards, running backs
  { symbol: 'NVDAx', companyName: 'NVIDIA', mint: 'Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh', tier: 'growth' },
  { symbol: 'METAx', companyName: 'Meta Platforms', mint: 'Xsa62P5mvPszXL1krVUnU5ar38bBSVcWAB6fmPCo5Zu', tier: 'growth' },
  { symbol: 'NFLXx', companyName: 'Netflix', mint: 'XsEH7wWfJJu2ZT3UCFeVfALnVA6CP5ur7Ee11KmzVpL', tier: 'growth' },
  { symbol: 'AVGOx', companyName: 'Broadcom', mint: 'XsgSaSvNSqLTtFuyWPBhK9196Xb9Bbdyjj4fH3cPJGo', tier: 'growth' },
  { symbol: 'AMDx', companyName: 'AMD', mint: 'XsXcJ6GZ9kVnjqGsjBnktRcuwMBmvKWh8S93RefZ1rF', tier: 'growth' },
  { symbol: 'CRMx', companyName: 'Salesforce', mint: 'XsczbcQ3zfcgAEt9qHQES8pxKAVG5rujPSHQEXi4kaN', tier: 'growth' },

  // Momentum: strikers, receivers
  { symbol: 'TSLAx', companyName: 'Tesla', mint: 'XsDoVfqeBukxuZHWhdvWHBhgEHjGNst4MLodqsJHzoB', tier: 'momentum' },
  { symbol: 'COINx', companyName: 'Coinbase', mint: 'Xs7ZdzSHLU9ftNJsii5fCeJhoRWSC32SQGzGQtePxNu', tier: 'momentum' },
  { symbol: 'MSTRx', companyName: 'Strategy', mint: 'XsP7xzNPvEHS1m6qfanPUGjNmdnmsLKEoNAnHjdxxyZ', tier: 'momentum' },
  { symbol: 'HOODx', companyName: 'Robinhood', mint: 'XsvNBAYkrDRNhA7wPHQfX3ZUXZyZLdnCQDfHZ56bzpg', tier: 'momentum' },
  { symbol: 'PLTRx', companyName: 'Palantir', mint: 'XsoBhf2ufR8fTyNSjqfU71DYGaE6Z3SUGAidpzriAA4', tier: 'momentum' },
  { symbol: 'GMEx', companyName: 'GameStop', mint: 'Xsf9mBktVB9BSU5kf4nHxPq5hCBJ2j2ui3ecFGxPRGc', tier: 'momentum' },
];

/**
 * Sectors, for the portfolio-building layer (SCORING_PLAN.md Phase 5): the
 * team balance bonus and the weekly portfolio health card.
 *
 * Curated once, here, by ticker (without the xStock "x"). A listing can carry
 * its own in `xstocks.sector`, which wins: that's how a new asset class
 * brings its own. Anything unknown has no sector and simply doesn't count
 * toward balance.
 */
export const SECTORS = {
  technology: 'Technology',
  communication: 'Communication',
  consumer_discretionary: 'Consumer discretionary',
  consumer_staples: 'Consumer staples',
  health_care: 'Health care',
  financials: 'Financials',
  energy: 'Energy',
  industrials: 'Industrials',
  materials: 'Materials',
  utilities: 'Utilities',
  real_estate: 'Real estate',
  crypto: 'Crypto',
  index_funds: 'Index funds',
  commodities: 'Commodities',
} as const;

export type Sector = keyof typeof SECTORS;

const BY_TICKER: Record<string, Sector> = {
  // Technology
  AAPL: 'technology', MSFT: 'technology', NVDA: 'technology', AVGO: 'technology', AMD: 'technology',
  ORCL: 'technology', CRM: 'technology', ADBE: 'technology', INTC: 'technology', CSCO: 'technology',
  IBM: 'technology', QCOM: 'technology', TXN: 'technology', MU: 'technology', ACN: 'technology',
  PLTR: 'technology', CRWD: 'technology', PANW: 'technology', SNOW: 'technology', NET: 'technology',
  DDOG: 'technology', ZS: 'technology', OKTA: 'technology', SHOP: 'technology', APP: 'technology',
  ARM: 'technology', ASML: 'technology', TSM: 'technology', DELL: 'technology', SMCI: 'technology',
  NOW: 'technology', INTU: 'technology', AMAT: 'technology', LRCX: 'technology', MRVL: 'technology',
  // Communication
  GOOGL: 'communication', GOOG: 'communication', META: 'communication', NFLX: 'communication',
  DIS: 'communication', CMCSA: 'communication', T: 'communication', VZ: 'communication',
  TMUS: 'communication', SPOT: 'communication', RBLX: 'communication', RDDT: 'communication',
  // Consumer discretionary
  AMZN: 'consumer_discretionary', TSLA: 'consumer_discretionary', HD: 'consumer_discretionary',
  MCD: 'consumer_discretionary', NKE: 'consumer_discretionary', SBUX: 'consumer_discretionary',
  LOW: 'consumer_discretionary', BKNG: 'consumer_discretionary', ABNB: 'consumer_discretionary',
  UBER: 'consumer_discretionary', GME: 'consumer_discretionary', AMC: 'consumer_discretionary',
  F: 'consumer_discretionary', GM: 'consumer_discretionary', RIVN: 'consumer_discretionary',
  CVNA: 'consumer_discretionary', DKNG: 'consumer_discretionary', MELI: 'consumer_discretionary',
  BABA: 'consumer_discretionary', PDD: 'consumer_discretionary', CMG: 'consumer_discretionary',
  // Consumer staples
  KO: 'consumer_staples', PEP: 'consumer_staples', PG: 'consumer_staples', WMT: 'consumer_staples',
  COST: 'consumer_staples', TGT: 'consumer_staples', PM: 'consumer_staples', MO: 'consumer_staples',
  CL: 'consumer_staples', MDLZ: 'consumer_staples',
  // Health care
  JNJ: 'health_care', LLY: 'health_care', UNH: 'health_care', PFE: 'health_care', MRK: 'health_care',
  ABBV: 'health_care', ABT: 'health_care', TMO: 'health_care', AMGN: 'health_care', GILD: 'health_care',
  NVO: 'health_care', AZN: 'health_care', ISRG: 'health_care', MDT: 'health_care', HIMS: 'health_care',
  // Financials
  JPM: 'financials', V: 'financials', MA: 'financials', BAC: 'financials', GS: 'financials',
  MS: 'financials', WFC: 'financials', C: 'financials', 'BRK.B': 'financials', BLK: 'financials',
  AXP: 'financials', SCHW: 'financials', PYPL: 'financials', SQ: 'financials', XYZ: 'financials',
  HOOD: 'financials', SOFI: 'financials', AFRM: 'financials', UPST: 'financials', NU: 'financials',
  // Crypto: miners, treasuries and exchanges move with crypto, not their nominal sector.
  COIN: 'crypto', MSTR: 'crypto', MARA: 'crypto', RIOT: 'crypto', CRCL: 'crypto', BMNR: 'crypto',
  SBET: 'crypto', GLXY: 'crypto', BLSH: 'crypto',
  // Energy
  XOM: 'energy', CVX: 'energy', COP: 'energy', OXY: 'energy', SLB: 'energy', OKLO: 'energy',
  // Industrials
  BA: 'industrials', CAT: 'industrials', GE: 'industrials', HON: 'industrials', LMT: 'industrials',
  RTX: 'industrials', DE: 'industrials', UPS: 'industrials', UNP: 'industrials', RKLB: 'industrials',
  // Materials, utilities, real estate
  LIN: 'materials', NEM: 'materials', FCX: 'materials',
  NEE: 'utilities', DUK: 'utilities', SO: 'utilities', VST: 'utilities', CEG: 'utilities',
  AMT: 'real_estate', PLD: 'real_estate', O: 'real_estate',
  // Funds
  SPY: 'index_funds', QQQ: 'index_funds', VTI: 'index_funds', IWM: 'index_funds', DIA: 'index_funds',
  TQQQ: 'index_funds', VOO: 'index_funds',
  GLD: 'commodities', SLV: 'commodities', USO: 'commodities',
};

/** "AAPLx" -> "AAPL". */
export const tickerOf = (symbol: string): string => symbol.replace(/x$/, '');

/** A listing's sector: its own if it has one, else the curated map's. */
export function sectorOf(symbol: string, own?: string | null): Sector | null {
  if (own && Object.hasOwn(SECTORS, own)) return own as Sector;
  return BY_TICKER[tickerOf(symbol)] ?? null;
}

export const sectorLabel = (sector: Sector): string => SECTORS[sector];

import { XSTOCKS_SEED } from '../xstocks/xstocks.seed.js';
import { sectorLabel, sectorOf, tickerOf } from './sectors.js';

describe('sectors', () => {
  it('knows every stock in the original catalogue', () => {
    const missing = XSTOCKS_SEED.filter((s) => sectorOf(s.symbol) === null).map((s) => s.symbol);
    expect(missing).toEqual([]);
  });

  it('reads the ticker without the xStock suffix', () => {
    expect(tickerOf('AAPLx')).toBe('AAPL');
    expect(tickerOf('BRK.Bx')).toBe('BRK.B');
    expect(sectorOf('BRK.Bx')).toBe('financials');
    expect(sectorOf('COINx')).toBe('crypto');
    expect(sectorLabel('consumer_staples')).toBe('Consumer staples');
  });

  it("lets a listing's own sector win, and ignores one it doesn't know", () => {
    expect(sectorOf('GLDx', 'commodities')).toBe('commodities');
    expect(sectorOf('AAPLx', 'not-a-sector')).toBe('technology');
    expect(sectorOf('UNKNOWNx')).toBeNull();
  });
});

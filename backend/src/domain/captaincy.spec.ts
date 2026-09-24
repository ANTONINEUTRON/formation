import { captaincyRules, parseCaptaincy } from './captaincy.js';

describe('captaincyRules', () => {
  it('matches the scoring doc', () => {
    expect(captaincyRules('football')).toEqual({ captain: true, vice: true, multiplier: 2 });
    expect(captaincyRules('basketball')).toEqual({ captain: true, vice: false, multiplier: 1.5 });
    expect(captaincyRules('american_football')).toEqual({
      captain: false,
      vice: false,
      multiplier: 1,
    });
  });
});

describe('parseCaptaincy', () => {
  it('accepts a captain and vice-captain in football', () => {
    expect(parseCaptaincy('football', { captainSlot: 9, viceCaptainSlot: 0 }, '4-4-2')).toEqual({
      captainSlot: 9,
      viceCaptainSlot: 0,
    });
  });

  it('ignores a vice-captain in basketball', () => {
    expect(parseCaptaincy('basketball', { captainSlot: 1, viceCaptainSlot: 2 }, null)).toEqual({
      captainSlot: 1,
      viceCaptainSlot: null,
    });
  });

  it('rejects american football, out-of-range slots and a duplicate armband', () => {
    expect(() => parseCaptaincy('american_football', { captainSlot: 0 }, null)).toThrow(
      "don't have a captain",
    );
    expect(() => parseCaptaincy('football', { captainSlot: 11 }, '4-4-2')).toThrow('between 0 and 10');
    expect(() => parseCaptaincy('basketball', { captainSlot: 5 }, null)).toThrow('between 0 and 4');
    expect(() =>
      parseCaptaincy('football', { captainSlot: 3, viceCaptainSlot: 3 }, '4-4-2'),
    ).toThrow('different player');
  });

  it('allows clearing the armbands', () => {
    expect(parseCaptaincy('football', {}, '4-4-2')).toEqual({
      captainSlot: null,
      viceCaptainSlot: null,
    });
  });
});

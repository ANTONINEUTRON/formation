import { parseFormation, remapFormation } from './formation.js';
import { footballShape, rosterShape } from './sport.js';

describe('parseFormation', () => {
  it('accepts every valid formation', () => {
    for (const name of ['3-4-3', '3-5-2', '4-3-3', '4-4-2', '4-5-1', '5-2-3', '5-3-2', '5-4-1']) {
      expect(parseFormation(name)).toBe(name);
    }
  });

  it('rejects shapes outside the rules', () => {
    expect(() => parseFormation('2-5-3')).toThrow('not a valid formation');
    expect(() => parseFormation('4-4-3')).toThrow('not a valid formation');
    expect(() => parseFormation('')).toThrow();
    expect(() => parseFormation(442)).toThrow('formation is required');
  });
});

describe('footballShape', () => {
  it('always has 11 slots: GK, defenders, midfielders, forwards', () => {
    const shape = footballShape('3-5-2');
    expect(shape).toHaveLength(11);
    expect(shape.map((s) => s.label)).toEqual([
      'GK', 'DEF', 'DEF', 'DEF', 'MID', 'MID', 'MID', 'MID', 'MID', 'FWD', 'FWD',
    ]);
    expect(shape[0].tier).toBe('blue_chip');
    expect(shape.at(-1)!.tier).toBe('momentum');
  });

  it('is the shape rosterShape returns for football', () => {
    expect(rosterShape('football', '5-3-2')).toEqual(footballShape('5-3-2'));
    expect(rosterShape('basketball')).toHaveLength(5);
    expect(rosterShape('american_football')).toHaveLength(9);
  });
});

describe('remapFormation', () => {
  // 4-4-2: 0 GK, 1-4 DEF, 5-8 MID, 9-10 FWD
  const slots = [
    { slot_index: 0, token_mint: 'gk' },
    { slot_index: 1, token_mint: 'd1' },
    { slot_index: 2, token_mint: 'd2' },
    { slot_index: 3, token_mint: 'd3' },
    { slot_index: 4, token_mint: 'd4' },
    { slot_index: 5, token_mint: 'm1' },
    { slot_index: 6, token_mint: 'm2' },
    { slot_index: 7, token_mint: 'm3' },
    { slot_index: 8, token_mint: 'm4' },
    { slot_index: 9, token_mint: 'f1' },
    { slot_index: 10, token_mint: 'f2' },
  ];

  it('keeps picks in order and drops what no longer fits', () => {
    // 3-5-2: one defender too many, and a midfield slot left empty.
    const result = remapFormation({
      from: '4-4-2',
      to: '3-5-2',
      slots,
      captainSlot: 9,
      viceCaptainSlot: 1,
    });

    expect(result.dropped).toEqual(['d4']);
    expect(result.slots).toEqual([
      { slot_index: 0, token_mint: 'gk' },
      { slot_index: 1, token_mint: 'd1' },
      { slot_index: 2, token_mint: 'd2' },
      { slot_index: 3, token_mint: 'd3' },
      { slot_index: 4, token_mint: 'm1' },
      { slot_index: 5, token_mint: 'm2' },
      { slot_index: 6, token_mint: 'm3' },
      { slot_index: 7, token_mint: 'm4' },
      { slot_index: 9, token_mint: 'f1' },
      { slot_index: 10, token_mint: 'f2' },
    ]);
  });

  it('moves the armbands with their stocks', () => {
    const result = remapFormation({
      from: '4-4-2',
      to: '3-5-2',
      slots,
      captainSlot: 9, // f1 → still slot 9
      viceCaptainSlot: 5, // m1 → moves to slot 4
    });
    expect(result.captainSlot).toBe(9);
    expect(result.viceCaptainSlot).toBe(4);
  });

  it('clears an armband whose stock was dropped', () => {
    const result = remapFormation({
      from: '4-4-2',
      to: '3-5-2',
      slots,
      captainSlot: 4, // d4 is dropped
      viceCaptainSlot: null,
    });
    expect(result.captainSlot).toBeNull();
  });

  it('leaves new slots empty when a role gains places', () => {
    const result = remapFormation({
      from: '4-4-2',
      to: '5-4-1',
      slots,
      captainSlot: null,
      viceCaptainSlot: null,
    });
    // The fifth defender slot has no pick yet; one forward is dropped.
    expect(result.slots.filter((s) => s.slot_index === 5)).toHaveLength(0);
    expect(result.dropped).toEqual(['f2']);
    expect(result.slots).toHaveLength(10);
  });
});

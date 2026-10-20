import { gradeAbove, gradeBelow, staleness, worst } from './health.js';

describe('health thresholds', () => {
  it('grades a value that is worse when higher', () => {
    expect(gradeAbove(5, 10, 20)).toBe('green');
    expect(gradeAbove(10, 10, 20)).toBe('green');
    expect(gradeAbove(11, 10, 20)).toBe('amber');
    expect(gradeAbove(21, 10, 20)).toBe('red');
    expect(gradeAbove(null, 10, 20)).toBe('unknown');
  });

  it('grades a value that is worse when lower', () => {
    expect(gradeBelow(0.6, 0.5, 0.25)).toBe('green');
    expect(gradeBelow(0.4, 0.5, 0.25)).toBe('amber');
    expect(gradeBelow(0.2, 0.5, 0.25)).toBe('red');
  });

  it('follows the tick interval, so an hourly server is not late at 20 minutes', () => {
    const hourly = staleness(60);
    expect(gradeAbove(20 * 60_000, hourly.priceTick.amber, hourly.priceTick.red)).toBe('green');
    const fast = staleness(5);
    expect(gradeAbove(21 * 60_000, fast.priceTick.amber, fast.priceTick.red)).toBe('red');
  });

  it('takes the worst level', () => {
    expect(worst(['green', 'amber', 'unknown'])).toBe('amber');
    expect(worst(['green', 'red'])).toBe('red');
    expect(worst(['unknown'])).toBe('unknown');
  });
});

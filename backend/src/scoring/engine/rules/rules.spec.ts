import type { SessionReturn, SlotContext } from '../types.js';
import { americanFootballRules } from './american-football.js';
import { basketballRules } from './basketball.js';
import { footballRules } from './football.js';

const session = (change: number): SessionReturn => ({
  start: 0,
  end: 1,
  open: 100,
  close: 100 * (1 + change),
  change,
});

const ctx = (overrides: Partial<SlotContext> = {}): SlotContext => ({
  role: 'MID',
  ownReturn: 0,
  alpha: 0,
  startPrice: 100,
  lowestRelative: 1,
  sessions: [],
  benchmarkSessions: [],
  ...overrides,
});

const points = (events: { code: string; points: number }[], code: string) =>
  events.filter((e) => e.code === code).reduce((sum, e) => sum + e.points, 0);

describe('football rules', () => {
  it('pays goals by role, one per full 3%', () => {
    expect(points(footballRules.slotEvents(ctx({ role: 'FWD', ownReturn: 0.075 })), 'goal')).toBe(8);
    expect(points(footballRules.slotEvents(ctx({ role: 'DEF', ownReturn: 0.03 })), 'goal')).toBe(6);
    expect(points(footballRules.slotEvents(ctx({ role: 'MID', ownReturn: 0.03 })), 'goal')).toBe(5);
    expect(points(footballRules.slotEvents(ctx({ ownReturn: 0.0299 })), 'goal')).toBe(0);
  });

  it('pays an assist at exactly 1% alpha', () => {
    expect(points(footballRules.slotEvents(ctx({ alpha: 0.01 })), 'assist')).toBe(3);
    expect(points(footballRules.slotEvents(ctx({ alpha: 0.0099 })), 'assist')).toBe(0);
  });

  it('pays clean sheets to defenders and midfielders only', () => {
    expect(points(footballRules.slotEvents(ctx({ role: 'GK', ownReturn: 0 })), 'clean_sheet')).toBe(4);
    expect(points(footballRules.slotEvents(ctx({ role: 'MID', ownReturn: 0.001 })), 'clean_sheet')).toBe(1);
    expect(points(footballRules.slotEvents(ctx({ role: 'FWD', ownReturn: 0.001 })), 'clean_sheet')).toBe(0);
  });

  it('concedes one point per full 2% loss, defence only', () => {
    expect(points(footballRules.slotEvents(ctx({ role: 'DEF', ownReturn: -0.045 })), 'conceded')).toBe(-2);
    expect(points(footballRules.slotEvents(ctx({ role: 'MID', ownReturn: -0.045 })), 'conceded')).toBe(0);
  });
});

describe('basketball rules', () => {
  it('pays buckets to guards only, one per full 1%', () => {
    expect(points(basketballRules.slotEvents(ctx({ role: 'PG', ownReturn: 0.032 })), 'bucket')).toBe(6);
    expect(points(basketballRules.slotEvents(ctx({ role: 'SF', ownReturn: 0.032 })), 'bucket')).toBe(0);
  });

  it('pays the centre a block per session it holds up while the market falls', () => {
    const events = basketballRules.slotEvents(
      ctx({
        role: 'C',
        sessions: [session(0.001), session(-0.01), session(0)],
        benchmarkSessions: [session(-0.02), session(-0.01), session(0.01)],
      }),
    );
    expect(points(events, 'block')).toBe(5);
  });

  it('pays a double-double per session two picks beat the market by 1%', () => {
    const benchmarkSessions = [session(0), session(0)];
    const contexts = [
      ctx({ sessions: [session(0.02), session(0)], benchmarkSessions }),
      ctx({ sessions: [session(0.015), session(0)], benchmarkSessions }),
      ctx({ sessions: [session(-0.01), session(0)], benchmarkSessions }),
    ];
    expect(points(basketballRules.teamEvents!(contexts), 'double_double')).toBe(5);
  });
});

describe('american football rules', () => {
  it('pays touchdowns per full 4% and turnovers per full -4%', () => {
    expect(points(americanFootballRules.slotEvents(ctx({ role: 'WR', ownReturn: 0.09 })), 'touchdown')).toBe(12);
    expect(points(americanFootballRules.slotEvents(ctx({ role: 'RB', ownReturn: -0.05 })), 'turnover')).toBe(-2);
    expect(points(americanFootballRules.slotEvents(ctx({ role: 'K', ownReturn: -0.05 })), 'turnover')).toBe(0);
  });

  it('pays receptions for green sessions to receivers and tight ends', () => {
    const sessions = [session(0.01), session(-0.01), session(0.02)];
    expect(points(americanFootballRules.slotEvents(ctx({ role: 'WR', sessions })), 'reception')).toBe(1);
    expect(points(americanFootballRules.slotEvents(ctx({ role: 'RB', sessions })), 'reception')).toBe(0);
  });

  it('pays a clean pocket only while the quarterback stays above 98%', () => {
    expect(points(americanFootballRules.slotEvents(ctx({ role: 'QB', lowestRelative: 0.98 })), 'clean_pocket')).toBe(4);
    expect(points(americanFootballRules.slotEvents(ctx({ role: 'QB', lowestRelative: 0.979 })), 'clean_pocket')).toBe(0);
  });

  it('pays the kicker a field goal per green session', () => {
    const sessions = [session(0.001), session(0.001), session(-0.5)];
    expect(points(americanFootballRules.slotEvents(ctx({ role: 'K', sessions })), 'field_goal')).toBe(2);
  });
});

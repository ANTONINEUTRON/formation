import { CALENDAR } from '../../src/domain/calendar.js';
import type { GameCalendar } from '../../src/domain/calendar.js';
import type { AuthUser } from '../../src/domain/dto.js';
import { PortfolioService } from '../../src/scoring/portfolio.service.js';
import { createHarness } from './harness.js';
import type { Harness } from './harness.js';

/** SCORING_PLAN.md Phase 5: balance pays a little, and gets explained. */
describe('portfolio layer', () => {
  let h: Harness;
  let calendar: GameCalendar;
  let me: AuthUser;

  beforeAll(async () => {
    h = await createHarness();
    calendar = h.app.get<GameCalendar>(CALENDAR);
  });
  afterAll(async () => {
    await h.close();
  });
  beforeEach(async () => {
    await h.reset();
    me = await h.createPlayer('me');
  });

  const bonuses = () =>
    h.db
      .selectFrom('points_ledger')
      .select(['sport_mode', 'points', 'at'])
      .where('user_id', '=', me.id)
      .where('kind', '=', 'bonus')
      .execute();

  it('pays the balance bonus at full time to a team spanning four sectors, and only then', async () => {
    // Football: tech, staples, health care, financials, consumer discretionary.
    await h.draft(me, 'football');
    // Basketball: tech, communication, financials. One short.
    await h.draft(me, 'basketball');
    await h.priceTicks.tick();

    const week = calendar.weekAt(h.clock.now());
    h.clock.set(week.fullTime.getTime() + 5 * 60_000);
    await h.priceTicks.tick();

    const paid = await bonuses();
    expect(paid).toHaveLength(1);
    expect(paid[0]).toMatchObject({ sport_mode: 'football', points: 5 });
    // Banked at full time, so it counts toward the week it was earned in.
    expect(new Date(paid[0].at).getTime()).toBe(week.fullTime.getTime());

    // Another tick after full time doesn't pay it again.
    h.clock.advance(30);
    await h.priceTicks.tick();
    expect(await bonuses()).toHaveLength(1);
  });

  it('builds the health card: sectors, tiers, the bonus and plain lessons', async () => {
    await h.draft(me, 'basketball');
    await h.priceTicks.tick();
    const portfolio = h.app.get(PortfolioService);

    const card = await portfolio.health(me.id, 'basketball', h.clock.now());
    expect(card.sectors.map((s) => s.label)).toEqual(
      expect.arrayContaining(['Technology', 'Financials']),
    );
    expect(card.sectors.reduce((sum, s) => sum + s.sharePct, 0)).toBeGreaterThanOrEqual(99);
    expect(card.tiers).toEqual(
      expect.arrayContaining([
        { tier: 'momentum', count: 2 },
        { tier: 'balanced', count: 2 },
        { tier: 'blue_chip', count: 1 },
      ]),
    );
    expect(card.balance).toMatchObject({ sectors: 3, needed: 4, bonus: 5, earned: false });
    expect(card.lessons).toContain('1 more sector and your team earns the +5 balance bonus at full time.');
    expect(card.lessons.join(' ')).not.toMatch(/profit/i);

    // A pick that carried the week shows up by name.
    h.clock.advance(30);
    h.prices.move('mint-NVDA', 1.06);
    await h.priceTicks.tick();
    const later = await portfolio.health(me.id, 'basketball', h.clock.now());
    expect(later.carried?.symbol).toBe('NVDAx');
  });
});

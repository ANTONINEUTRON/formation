import type { EntryBreakdown, SlotScore } from './engine/types.js';
import { dailyPointsBody, summariseEvents } from './events-summary.js';

const slot = (symbol: string, events: { code: string; label: string; points: number }[]) =>
  ({ symbol, events }) as unknown as SlotScore;

describe('daily points message', () => {
  it('names the biggest moments with the stocks behind them', () => {
    const breakdown: EntryBreakdown = {
      total: 7,
      slots: [
        slot('KOx', [{ code: 'clean_sheet', label: 'Clean sheet', points: 3 }]),
        slot('NVDAx', [{ code: 'goal', label: '2 goals', points: 8 }]),
        slot('AAPLx', [{ code: 'conceded', label: '1 conceded', points: -2 }, { code: 'cap', label: 'Daily cap', points: -2 }]),
        slot('TSLAx', [{ code: 'assist', label: 'Assist', points: 1 }]),
      ],
      teamEvents: [],
    };
    expect(summariseEvents(breakdown)).toBe('2 goals from NVDAx, a clean sheet from KOx, 1 conceded from AAPLx and 1 more');
    expect(dailyPointsBody('football', breakdown)).toBe(
      'Your football team scored +7 points yesterday: 2 goals from NVDAx, a clean sheet from KOx, 1 conceded from AAPLx and 1 more.',
    );
  });

  it('reads naturally for one moment, a loss, and team events', () => {
    const one: EntryBreakdown = { total: 1, slots: [slot('TSLAx', [{ code: 'assist', label: 'Assist', points: 1 }])], teamEvents: [] };
    expect(dailyPointsBody('football', one)).toBe('Your football team scored +1 point yesterday: an assist from TSLAx.');

    const team: EntryBreakdown = { total: -3, slots: [], teamEvents: [{ code: 'turnover', label: 'Turnover', points: -3 }] };
    expect(dailyPointsBody('american football', team)).toBe('Your american football team scored -3 points yesterday: a turnover.');
  });
});

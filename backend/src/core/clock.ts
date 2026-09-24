/** Injection token for the clock, so tests can control time. */
export const CLOCK = 'CLOCK';

export interface Clock {
  /** Epoch milliseconds. */
  now(): number;
  date(): Date;
}

export const systemClock: Clock = {
  now: () => Date.now(),
  date: () => new Date(),
};

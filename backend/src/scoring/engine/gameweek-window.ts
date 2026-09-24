export interface GameweekConfig {
  /** Epoch all windows align to. */
  anchor: number;
  lengthMinutes: number;
}

export interface GameweekWindow {
  /** 1-based sequence number since the anchor. */
  number: number;
  start: number;
  end: number;
}

/** The gameweek containing [at]. Windows tile the timeline from the anchor. */
export function gameweekWindow(at: number, config: GameweekConfig): GameweekWindow {
  const length = Math.max(1, config.lengthMinutes) * 60_000;
  const index = Math.floor((at - config.anchor) / length);
  const start = config.anchor + index * length;
  return { number: index + 1, start, end: start + length };
}

export function nextGameweek(window: GameweekWindow, config: GameweekConfig): GameweekWindow {
  return gameweekWindow(window.end, config);
}

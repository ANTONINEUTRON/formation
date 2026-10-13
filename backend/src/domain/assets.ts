/**
 * What kind of thing a listed asset is, which decides the benchmark its alpha
 * is measured against.
 *
 * To onboard a new kind of tokenized asset:
 *   1. list it with its class (a catalogue source sets `xstocks.asset_class`);
 *   2. map the class to a benchmark here;
 *   3. eligibility decides when it starts scoring, by the same rules as
 *      everything else. No scoring code changes.
 */
export const ASSET_CLASSES = {
  us_equity: { label: 'US equity', benchmarkSymbol: 'SPYx' },
  commodity: { label: 'Commodity', benchmarkSymbol: 'GLDx' },
} as const;

export type AssetClass = keyof typeof ASSET_CLASSES;

export const DEFAULT_ASSET_CLASS: AssetClass = 'us_equity';

export function isAssetClass(value: string): value is AssetClass {
  return Object.hasOwn(ASSET_CLASSES, value);
}

/**
 * The benchmark mint for an asset class. Falls back to [defaultBenchmark] (the
 * configured SPYx mint) for US equities, unknown classes, and classes whose
 * benchmark isn't listed yet.
 */
export function benchmarkMintFor(
  assetClass: string,
  mintBySymbol: Map<string, string>,
  defaultBenchmark: string,
): string {
  if (!isAssetClass(assetClass) || assetClass === DEFAULT_ASSET_CLASS) return defaultBenchmark;
  return mintBySymbol.get(ASSET_CLASSES[assetClass].benchmarkSymbol) ?? defaultBenchmark;
}

/**
 * Restarts season 1 on a new date, for a fresh start before the game's real
 * launch. Everything banked before the new kick-off becomes pre-season: kept in
 * the ledger as season 0, but out of every season total. Week-by-week stats,
 * skill ratings and badges from before it are cleared, and match weeks are
 * rebuilt from the new calendar.
 *
 *   npm run season:reset -- 2026-10-19                  # preview
 *   npm run season:reset -- 2026-10-19 --apply          # do it
 *   ... --db SUPABASE_DATABASE_URL                      # another database
 *
 * The date is the ET Monday of the new week 1 and must match SEASON_ANCHOR on
 * the server. Safe to run again: a second run only catches up anything the
 * server banked in between. It refuses once any season has been finalised.
 */
import { sql } from 'kysely';
import { createDb } from '../core/db.js';
import { GameCalendar } from '../domain/calendar.js';

try {
  process.loadEnvFile();
} catch {
  // No .env file; use the real environment.
}

const args = process.argv.slice(2);
const anchor = args.find((a) => /^\d{4}-\d{2}-\d{2}$/.test(a));
const apply = args.includes('--apply');
const dbVar = args.includes('--db') ? args[args.indexOf('--db') + 1] : 'DATABASE_URL';
const url = process.env[dbVar];
if (!anchor || !url) {
  console.error('Usage: npm run season:reset -- YYYY-MM-DD [--apply] [--db ENV_VAR]');
  process.exit(1);
}

const calendar = new GameCalendar(anchor);
const season = calendar.season(1);
const start = season.startsAt;
const db = createDb(url);

const [finalized] = await db
  .selectFrom('seasons')
  .select((eb) => eb.fn.countAll<string>().as('n'))
  .where('finalized_at', 'is not', null)
  .execute();
if (Number(finalized.n) > 0) {
  console.error('A season has already been finalised; refusing to restart.');
  process.exit(1);
}

const count = async (query: Promise<{ n: string | number }[]>) => Number((await query)[0].n);
const preview = {
  ledgerToPreSeason: await count(
    db
      .selectFrom('points_ledger')
      .select((eb) => eb.fn.countAll<string>().as('n'))
      .where('at', '<', start)
      .where((eb) => eb.or([eb('season', 'is', null), eb('season', '<>', 0)]))
      .execute(),
  ),
  seasonTotalsToRecount: await count(
    db.selectFrom('classic_scores').select((eb) => eb.fn.countAll<string>().as('n')).execute(),
  ),
  matchWeeks: await count(db.selectFrom('match_weeks').select((eb) => eb.fn.countAll<string>().as('n')).execute()),
  weeklyStats: await count(db.selectFrom('weekly_stats').select((eb) => eb.fn.countAll<string>().as('n')).execute()),
  skillRatings: await count(db.selectFrom('skill_ratings').select((eb) => eb.fn.countAll<string>().as('n')).execute()),
  badgesBefore: await count(
    db
      .selectFrom('badges')
      .select((eb) => eb.fn.countAll<string>().as('n'))
      .where('awarded_at', '<', start)
      .execute(),
  ),
  scheduledFixtures: await count(
    db
      .selectFrom('league_fixtures')
      .select((eb) => eb.fn.countAll<string>().as('n'))
      .where('status', '=', 'scheduled')
      .execute(),
  ),
};

console.log(`Season 1 restarts ${start.toISOString()} (week 1 kick-off), ending ${season.endsAt.toISOString()}.`);
console.log(preview);
if (preview.scheduledFixtures > 0) {
  console.warn('Note: scheduled league fixtures keep their old week numbers; check them after the reset.');
}

if (!apply) {
  console.log('Preview only. Run with --apply to restart the season.');
  await db.destroy();
  process.exit(0);
}

await db.transaction().execute(async (trx) => {
  await trx
    .insertInto('seasons')
    .values({ number: 1, starts_at: season.startsAt, ends_at: season.endsAt })
    .onConflict((oc) => oc.column('number').doUpdateSet({ starts_at: season.startsAt, ends_at: season.endsAt }))
    .execute();
  await trx.deleteFrom('seasons').where('number', '>', 1).execute();
  // Rebuilt from the new calendar on the next tick, announcements unsent.
  await trx.deleteFrom('match_weeks').execute();

  await trx
    .updateTable('points_ledger')
    .set({ season: 0 })
    .where('at', '<', start)
    .where((eb) => eb.or([eb('season', 'is', null), eb('season', '<>', 0)]))
    .execute();
  // Season totals become exactly what season 1 has banked: nothing, before kick-off.
  await sql`
    update classic_scores c set total_points = coalesce((
      select sum(l.points) from points_ledger l
      where l.user_id = c.user_id and l.sport_mode = c.sport_mode and l.season = 1
    ), 0), updated_at = now()
  `.execute(trx);

  await trx.deleteFrom('weekly_stats').execute();
  await trx.deleteFrom('skill_ratings').execute();
  await trx.deleteFrom('badges').where('awarded_at', '<', start).execute();
});

console.log('Season 1 restarted.');
await db.destroy();

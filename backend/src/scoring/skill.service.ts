import { Inject, Injectable } from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import type { MatchWeek } from '../domain/calendar.js';
import type { SkillDto } from '../domain/dto.js';
import { SPORT_MODES } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';
import { round1 } from './engine/metrics.js';
import { SKILL_MIN_WEEKS, skillRating, weekForm, weekStats } from './engine/skill.js';
import { NotificationsService } from '../notifications/notifications.service.js';

/** Weekly badges, one winner per sport per match week. */
const WEEKLY_BADGES = {
  golden_boot: 'Golden Boot',
  clean_sheet_king: 'Clean-sheet king',
  shrewd_captain: 'Shrewd captain',
} as const;

/** What each badge was for, in the notification that announces it. */
const BADGE_REASONS: Record<keyof typeof WEEKLY_BADGES, (sport: string, week: number) => string> = {
  golden_boot: (sport, week) => `Most goals in ${sport} in match week ${week}.`,
  clean_sheet_king: (sport, week) => `Most clean sheets in ${sport} in match week ${week}.`,
  shrewd_captain: (sport, week) => `Your ${sport} captain beat your team's average by the most in match week ${week}.`,
};

/**
 * Makes skill visible (SCORING_PLAN.md §3.2). At full time each player's week
 * is summarised from the ledger into weekly_stats, their skill rating is
 * recomputed from every week they've played, and the week's badges go out.
 */
@Injectable()
export class SkillService {
  constructor(
    @Inject(DB) private readonly db: Db,
    private readonly notifications: NotificationsService,
  ) {}

  /** Summarises [week] for every player and refreshes their ratings. */
  async computeWeek(week: MatchWeek, now: number): Promise<void> {
    for (const mode of SPORT_MODES) {
      const rows = await this.db
        .selectFrom('points_ledger')
        .innerJoin('users', 'users.id', 'points_ledger.user_id')
        .select([
          'points_ledger.user_id as user_id',
          'points_ledger.kind as kind',
          'points_ledger.points as points',
          'points_ledger.detail as detail',
        ])
        .where('points_ledger.sport_mode', '=', mode)
        .where('points_ledger.at', '>=', week.kickOff)
        .where('points_ledger.at', '<=', week.fullTime)
        .where('users.is_seed', '=', false)
        .execute();

      const byUser = new Map<string, typeof rows>();
      for (const row of rows) {
        const list = byUser.get(row.user_id) ?? [];
        list.push(row);
        byUser.set(row.user_id, list);
      }

      const weekly = [...byUser.entries()]
        .map(([userId, list]) => ({ userId, stats: weekStats(list) }))
        // A week with no picks scored isn't a week of skill to judge.
        .filter(({ stats }) => stats.picks > 0);

      for (const { userId, stats } of weekly) {
        await this.db
          .insertInto('weekly_stats')
          .values({
            user_id: userId,
            sport_mode: mode,
            week: week.number,
            points: stats.points,
            alpha: stats.alpha,
            picks: stats.picks,
            picks_beating: stats.picksBeating,
            goals: stats.goals,
            clean_sheets: stats.cleanSheets,
            captain_points: stats.captainPoints,
            average_pick_points: stats.averagePickPoints,
          })
          .onConflict((oc) =>
            oc.columns(['user_id', 'sport_mode', 'week']).doUpdateSet((eb) => ({
              points: eb.ref('excluded.points'),
              alpha: eb.ref('excluded.alpha'),
              picks: eb.ref('excluded.picks'),
              picks_beating: eb.ref('excluded.picks_beating'),
              goals: eb.ref('excluded.goals'),
              clean_sheets: eb.ref('excluded.clean_sheets'),
              captain_points: eb.ref('excluded.captain_points'),
              average_pick_points: eb.ref('excluded.average_pick_points'),
            })),
          )
          .execute();
        await this.refreshRating(userId, mode, now);
      }

      await this.awardWeeklyBadges(mode, week, weekly, now);
    }
  }

  private async refreshRating(userId: string, mode: SportMode, now: number): Promise<void> {
    const weeks = await this.db
      .selectFrom('weekly_stats')
      .selectAll()
      .where('user_id', '=', userId)
      .where('sport_mode', '=', mode)
      .execute();
    const rating = skillRating(weeks.map((w) => w.alpha));
    const picks = weeks.reduce((s, w) => s + w.picks, 0);
    const beating = weeks.reduce((s, w) => s + w.picks_beating, 0);
    const captained = weeks.filter((w) => w.captain_points !== null && w.average_pick_points !== null);
    const shrewd = captained.filter((w) => (w.captain_points ?? 0) > (w.average_pick_points ?? 0));

    const values = {
      rating: rating.rating,
      weeks: weeks.length,
      mean_alpha: rating.meanAlpha,
      volatility: rating.volatility,
      hit_rate: picks > 0 ? beating / picks : 0,
      captain_rate: captained.length > 0 ? shrewd.length / captained.length : null,
      updated_at: new Date(now),
    };
    await this.db
      .insertInto('skill_ratings')
      .values({ user_id: userId, sport_mode: mode, ...values })
      .onConflict((oc) => oc.columns(['user_id', 'sport_mode']).doUpdateSet(values))
      .execute();
  }

  /**
   * Golden Boot for the most goals, Clean-sheet king (football) for the most
   * clean sheets, Shrewd captain for the captain who beat their team's
   * average by the most. Ties share it.
   */
  private async awardWeeklyBadges(
    mode: SportMode,
    week: MatchWeek,
    weekly: { userId: string; stats: ReturnType<typeof weekStats> }[],
    now: number,
  ): Promise<void> {
    const winners = (score: (s: ReturnType<typeof weekStats>) => number) => {
      const best = Math.max(0, ...weekly.map((w) => score(w.stats)));
      return best > 0 ? weekly.filter((w) => score(w.stats) === best).map((w) => w.userId) : [];
    };
    const awards: [keyof typeof WEEKLY_BADGES, string[]][] = [
      ['golden_boot', winners((s) => s.goals)],
      ['shrewd_captain', winners((s) => (s.captainPoints ?? 0) - (s.averagePickPoints ?? 0))],
    ];
    if (mode === 'football') awards.push(['clean_sheet_king', winners((s) => s.cleanSheets)]);

    const values = awards.flatMap(([code, users]) =>
      users.map((userId) => ({
        user_id: userId,
        code,
        label: `${WEEKLY_BADGES[code]} · S${week.season} W${week.weekOfSeason}`,
        sport_mode: mode,
        season: week.season,
        week: week.number,
        awarded_at: new Date(now),
      })),
    );
    if (values.length === 0) return;
    // Only the rows actually inserted are announced, so re-running a week
    // never repeats a notification.
    const awarded = await this.db
      .insertInto('badges')
      .values(values)
      .onConflict((oc) => oc.doNothing())
      .returning(['user_id', 'code'])
      .execute();
    const sport = mode.replace('_', ' ');
    await this.notifications.pushMany(
      awarded.map((b) => {
        const code = b.code as keyof typeof WEEKLY_BADGES;
        return {
          userId: b.user_id,
          kind: 'badge' as const,
          title: `Badge won: ${WEEKLY_BADGES[code]}`,
          body: BADGE_REASONS[code](sport, week.weekOfSeason),
          data: { code, mode, week: week.number },
        };
      }),
    );
  }

  /** A player's skill stats for a profile. Null before their first full week. */
  async skillFor(userId: string, mode: SportMode): Promise<SkillDto | null> {
    const [rating, recent] = await Promise.all([
      this.db
        .selectFrom('skill_ratings')
        .selectAll()
        .where('user_id', '=', userId)
        .where('sport_mode', '=', mode)
        .executeTakeFirst(),
      this.db
        .selectFrom('weekly_stats')
        .select(['week', 'points'])
        .where('user_id', '=', userId)
        .where('sport_mode', '=', mode)
        .orderBy('week', 'desc')
        .limit(5)
        .execute(),
    ]);
    if (!rating) return null;
    return {
      rating: rating.rating,
      weeks: rating.weeks,
      ranked: rating.weeks >= SKILL_MIN_WEEKS,
      alphaPerWeekPct: round1(rating.mean_alpha * 1000) / 10,
      hitRatePct: Math.round(rating.hit_rate * 100),
      shrewdCaptainPct: rating.captain_rate === null ? null : Math.round(rating.captain_rate * 100),
      form: recent.reverse().map((w) => weekForm(w.points)),
    };
  }
}

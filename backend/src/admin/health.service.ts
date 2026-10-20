import { Inject, Injectable } from '@nestjs/common';
import { sql } from 'kysely';
import { LLM_PROVIDER } from '../assistant/llm.js';
import type { LlmProvider } from '../assistant/llm.js';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import {
  AI_FAILURES,
  DB_SIZE,
  duration,
  gradeAbove,
  gradeBelow,
  LEAGUE_OVERDUE,
  MATCH_WEEK_STEP,
  PRICED_SHARE,
  staleness,
  worst,
} from './health.js';
import type { HealthCheck, HealthLevel } from './health.js';

export interface HealthDto {
  level: HealthLevel;
  checkedAt: string;
  checks: HealthCheck[];
}

const pct = (n: number) => `${Math.round(n * 100)}%`;

/**
 * "Is the game working?" in one read-only call: the scoring heartbeats, the
 * catalogue, the match week, leagues, pushes, the AI provider and the
 * database, each graded green, amber or red.
 */
@Injectable()
export class AdminHealthService {
  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(LLM_PROVIDER) private readonly llm: LlmProvider,
  ) {}

  async health(): Promise<HealthDto> {
    const now = this.clock.now();
    const checks = await Promise.all([
      this.heartbeats(now),
      this.priced(now),
      this.matchWeek(now),
      this.leagues(now),
      this.pushes(now),
      this.ai(now),
      this.database(),
    ]);
    const flat = checks.flat();
    return {
      level: worst(flat.map((c) => c.level)),
      checkedAt: new Date(now).toISOString(),
      checks: flat,
    };
  }

  private async heartbeats(now: number): Promise<HealthCheck[]> {
    const limits = staleness(this.config.priceTickMinutes);
    const [tick, bank, ledger] = await Promise.all([
      this.db.selectFrom('price_ticks').select((eb) => eb.fn.max('captured_at').as('at')).executeTakeFirst(),
      this.db.selectFrom('general_entries').select((eb) => eb.fn.max('last_banked_at').as('at')).executeTakeFirst(),
      this.db.selectFrom('points_ledger').select((eb) => eb.fn.max('at').as('at')).executeTakeFirst(),
    ]);
    const age = (at: unknown) => (at ? now - new Date(at as string).getTime() : null);
    const beat = (
      key: string,
      label: string,
      at: unknown,
      limit: { amber: number; red: number },
    ): HealthCheck => {
      const ms = age(at);
      return {
        key,
        label,
        level: gradeAbove(ms, limit.amber, limit.red),
        value: ms === null ? 'never' : `${duration(ms)} ago`,
        threshold: `amber after ${duration(limit.amber)}, red after ${duration(limit.red)}`,
      };
    };
    return [
      beat('price_tick', 'Last price tick', tick?.at, limits.priceTick),
      beat('bank', 'Last scoring bank', bank?.at, limits.bank),
      beat('ledger', 'Last ledger write', ledger?.at, limits.ledger),
    ];
  }

  /** Listed stocks with a price from the last two ticks: is the price feed working? */
  private async priced(now: number): Promise<HealthCheck> {
    const since = new Date(now - 2 * Math.max(1, this.config.priceTickMinutes) * 60_000);
    const [listed, fresh] = await Promise.all([
      this.db.selectFrom('xstocks').select((eb) => eb.fn.countAll<string>().as('n')).executeTakeFirstOrThrow(),
      this.db
        .selectFrom('price_ticks')
        .select((eb) => eb.fn.count<string>('mint').distinct().as('n'))
        .where('captured_at', '>=', since)
        .executeTakeFirstOrThrow(),
    ]);
    const total = Number(listed.n);
    const priced = Number(fresh.n);
    const share = total === 0 ? null : priced / total;
    return {
      key: 'stocks_priced',
      label: 'Stocks priced',
      level: gradeBelow(share, PRICED_SHARE.amber, PRICED_SHARE.red),
      value: total === 0 ? 'no stocks' : `${priced} of ${total} (${pct(share!)})`,
      threshold: `amber under ${pct(PRICED_SHARE.amber)}, red under ${pct(PRICED_SHARE.red)}`,
    };
  }


  private async matchWeek(now: number): Promise<HealthCheck> {
    const at = new Date(now);
    const week = await this.db
      .selectFrom('match_weeks')
      .selectAll()
      .where('kick_off', '<=', at)
      .orderBy('kick_off', 'desc')
      .limit(1)
      .executeTakeFirst();
    const threshold = `amber when a step is ${duration(MATCH_WEEK_STEP.amber)} overdue, red at ${duration(MATCH_WEEK_STEP.red)}`;
    if (!week) {
      return { key: 'match_week', label: 'Current match week', level: 'unknown', value: 'none started', threshold };
    }

    const kickOff = new Date(week.kick_off).getTime();
    const fullTime = new Date(week.full_time).getTime();
    const halfTime = kickOff + (fullTime - kickOff) / 2;
    const steps: { name: string; due: number; done: unknown }[] = [
      { name: 'kick-off', due: kickOff, done: week.kick_off_sent_at },
      { name: 'half-time', due: halfTime, done: week.half_time_sent_at },
      { name: 'full-time', due: fullTime, done: week.full_time_done_at },
    ];
    const overdue = steps
      .filter((s) => !s.done && now > s.due)
      .map((s) => ({ name: s.name, by: now - s.due }));
    const late = overdue.sort((a, b) => b.by - a.by)[0];
    return {
      key: 'match_week',
      label: `Match week ${week.number}`,
      level: late ? gradeAbove(late.by, MATCH_WEEK_STEP.amber, MATCH_WEEK_STEP.red) : 'green',
      value: late ? `${late.name} ${duration(late.by)} overdue` : now > fullTime ? 'finished' : 'on schedule',
      threshold,
    };
  }

  private async leagues(now: number): Promise<HealthCheck> {
    const stuck = await this.db
      .selectFrom('leagues')
      .select((eb) => [eb.fn.countAll<string>().as('n'), eb.fn.min('ends_at').as('oldest')])
      .where('status', '=', 'live')
      .where('ends_at', '<', new Date(now))
      .executeTakeFirstOrThrow();
    const count = Number(stuck.n);
    const by = stuck.oldest ? now - new Date(stuck.oldest as Date).getTime() : null;
    return {
      key: 'leagues',
      label: 'Leagues past their end',
      level: count === 0 ? 'green' : gradeAbove(by, LEAGUE_OVERDUE.amber, LEAGUE_OVERDUE.red),
      value: count === 0 ? 'none' : `${count} still live, oldest ${duration(by!)} over`,
      threshold: `amber for any, red when one is ${duration(LEAGUE_OVERDUE.red)} over`,
    };
  }

  private async pushes(now: number): Promise<HealthCheck> {
    const start = new Date(now);
    start.setUTCHours(0, 0, 0, 0);
    const row = await this.db
      .selectFrom('push_log')
      .select((eb) => eb.fn.countAll<string>().as('n'))
      .where('sent_at', '>=', start)
      .executeTakeFirstOrThrow();
    const enabled = this.config.fcmServiceAccount !== '';
    return {
      key: 'pushes',
      label: 'Pushes today (UTC)',
      level: enabled ? 'green' : 'amber',
      value: enabled ? `${Number(row.n)} sent` : 'FCM not configured',
      threshold: 'amber when FCM is off',
    };
  }

  private async ai(now: number): Promise<HealthCheck> {
    const start = new Date(now);
    start.setUTCHours(0, 0, 0, 0);
    const row = await this.db
      .selectFrom('assistant_usage')
      .select((eb) => [
        eb.fn.countAll<string>().as('total'),
        eb.fn.countAll<string>().filterWhere('succeeded', '=', false).as('failed'),
      ])
      .where('created_at', '>=', start)
      .executeTakeFirstOrThrow();
    const total = Number(row.total);
    const failed = Number(row.failed);
    const threshold = `amber over ${pct(AI_FAILURES.amber)} failed, red over ${pct(AI_FAILURES.red)}`;
    if (!this.llm.available) {
      return { key: 'ai', label: 'AI provider', level: 'red', value: 'not configured (GEMINI_API_KEY)', threshold };
    }
    const share = total === 0 ? 0 : failed / total;
    return {
      key: 'ai',
      label: 'AI provider',
      level: gradeAbove(share, AI_FAILURES.amber, AI_FAILURES.red),
      value: total === 0 ? 'no requests today' : `${failed} of ${total} failed today (${pct(share)})`,
      threshold,
    };
  }

  private async database(): Promise<HealthCheck> {
    const { rows } = await sql<{ size: string; connections: string }>`
      select pg_database_size(current_database()) as size,
             (select count(*) from pg_stat_activity where datname = current_database()) as connections
    `.execute(this.db);
    const bytes = Number(rows[0]?.size ?? 0);
    const mb = bytes / 1024 / 1024;
    const limit = this.config.dbSizeLimitMb;
    const share = limit > 0 ? mb / limit : null;
    return {
      key: 'database',
      label: 'Database',
      level: share === null ? 'green' : gradeAbove(share, DB_SIZE.amber, DB_SIZE.red),
      value:
        `${mb.toFixed(0)} MB` +
        (limit > 0 ? ` of ${limit} MB (${pct(share!)})` : '') +
        `, ${Number(rows[0]?.connections ?? 0)} connections`,
      threshold:
        limit > 0
          ? `amber at ${pct(DB_SIZE.amber)} of the plan, red at ${pct(DB_SIZE.red)}`
          : 'set DB_SIZE_LIMIT_MB to grade it',
    };
  }

}

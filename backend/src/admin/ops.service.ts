import { Inject, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { LeaguesService } from '../leagues/leagues.service.js';
import { PriceTickService } from '../scoring/price-tick.service.js';
import { XStocksCatalogueService } from '../xstocks/xstocks-catalogue.service.js';
import { AdminAuditService, requireReason, UUID } from './audit.service.js';
import type { AdminActionDto } from './audit.service.js';

/** Reason recorded for x-admin-key calls that don't send one, so scripts keep working. */
const SCRIPT_REASON = 'Script call (x-admin-key)';

export type OpName = 'catalogue.refresh' | 'scoring.tick' | 'leagues.process' | 'leagues.settle';

export interface OpResult {
  op: OpName;
  /** False when the job runs on in the background and reports in the log. */
  finished: boolean;
  result?: unknown;
  action: AdminActionDto;
}

/**
 * The operations panel: the jobs that otherwise run on timers, on demand.
 * Each records who ran it and why before it starts. Short jobs return their
 * result; long ones (the catalogue refresh walks every stock through Jupiter)
 * return straight away and log how they ended.
 */
@Injectable()
export class AdminOpsService {
  private readonly logger = new Logger(AdminOpsService.name);
  /** What's running now and its last outcome, for the page to poll. */
  private readonly status = new Map<OpName, { running: boolean; startedAt?: string; finishedAt?: string; error?: string }>();

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CLOCK) private readonly clock: Clock,
    private readonly audit: AdminAuditService,
    private readonly priceTicks: PriceTickService,
    private readonly leagues: LeaguesService,
    private readonly catalogue: XStocksCatalogueService,
  ) {}

  /** A wallet admin must explain; a script on the key gets a standard reason. */
  reasonFor(admin: string, value: unknown): string {
    if (admin === 'key' && (typeof value !== 'string' || value.trim() === '')) return SCRIPT_REASON;
    return requireReason(value);
  }

  async run(admin: string, op: OpName, reason: string, leagueId?: string): Promise<OpResult> {
    if (op === 'leagues.settle') {
      if (!leagueId || !UUID.test(leagueId)) throw new NotFoundException('No such league');
      const league = await this.db.selectFrom('leagues').select(['id', 'name', 'status']).where('id', '=', leagueId).executeTakeFirst();
      if (!league) throw new NotFoundException('No such league');
    }

    const { action } = await this.audit.run(
      { admin, action: `ops.${op}`, reason, detail: leagueId ? { leagueId } : undefined },
      async () => ({ result: null }),
    );

    const job = (): Promise<unknown> => {
      switch (op) {
        case 'catalogue.refresh':
          return this.catalogue.refresh();
        case 'scoring.tick':
          return this.priceTicks.tick();
        case 'leagues.process':
          return this.leagues.processDue();
        case 'leagues.settle':
          return this.leagues.settleById(leagueId!).then(() => ({ settled: leagueId }));
      }
    };

    this.status.set(op, { running: true, startedAt: this.clock.date().toISOString() });
    const done = job().then(
      (result) => {
        this.status.set(op, { running: false, finishedAt: this.clock.date().toISOString() });
        return result;
      },
      (e: unknown) => {
        this.status.set(op, { running: false, finishedAt: this.clock.date().toISOString(), error: String(e) });
        this.logger.error(`Admin op ${op} failed: ${String(e)}`);
        throw e;
      },
    );

    if (op === 'catalogue.refresh') {
      done.catch(() => undefined);
      return { op, finished: false, action };
    }
    // A failure stays an HTTP error, so scripts on the key notice it; the
    // audit record above still shows it was attempted.
    return { op, finished: true, result: await done, action };
  }

  statuses() {
    return Object.fromEntries(this.status);
  }

  /** Leagues worth acting on: live, or scheduled to start soon. */
  async leaguesList() {
    const rows = await this.db
      .selectFrom('leagues')
      .select((eb) => [
        'leagues.id as id',
        'leagues.name as name',
        'leagues.sport_mode as mode',
        'leagues.status as status',
        'leagues.starts_at as starts_at',
        'leagues.ends_at as ends_at',
        'leagues.max_members as max_members',
        eb
          .selectFrom('league_members')
          .select((m) => m.fn.countAll<string>().as('n'))
          .whereRef('league_members.league_id', '=', 'leagues.id')
          .as('members'),
      ])
      .where('leagues.status', 'in', ['live', 'scheduled'])
      .orderBy('leagues.ends_at', 'asc')
      .limit(100)
      .execute();
    const now = this.clock.now();
    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      mode: r.mode,
      status: r.status,
      startsAt: new Date(r.starts_at).toISOString(),
      endsAt: new Date(r.ends_at).toISOString(),
      overdue: r.status === 'live' && new Date(r.ends_at).getTime() < now,
      duel: r.max_members === 2,
      members: Number(r.members ?? 0),
    }));
  }
}

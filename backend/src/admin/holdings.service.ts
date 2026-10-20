import {
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { SchedulerRegistry } from '@nestjs/schedule';
import { sql } from 'kysely';
import { CLOCK } from '../core/clock.js';
import type { Clock } from '../core/clock.js';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { BALANCE_SOURCE, PRICE_SOURCE } from '../core/sources.js';
import type { BalanceSource, PriceSource } from '../core/sources.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { AdminAuditService } from './audit.service.js';
import type { AdminActionDto } from './audit.service.js';

/** RPC calls one wallet read costs: the classic token program and Token-2022. */
export const CALLS_PER_WALLET = 2;
const MINUTE = 60_000;
const DAY = 24 * 60 * MINUTE;
/** Manual refreshes of one wallet, and of every wallet, at most this often. */
const REFRESH_COOLDOWN_MS = 5 * MINUTE;
const SNAPSHOT_KEEP_DAYS = 90;
const BATCH_PAUSE_MS = 250;

export interface StockHoldingDto {
  mint: string;
  symbol: string;
  amount: number;
  usdValue: number | null;
  holders: number;
  draftedUsd: number;
}

export interface HoldingsOverviewDto {
  totalUsd: number;
  draftedUsd: number;
  walletsRead: number;
  walletsTotal: number;
  walletsStale: number;
  holders: number;
  snapshotTakenAt: string | null;
  byStock: StockHoldingDto[];
  topHolders: { id: string; username: string; walletAddress: string; usdValue: number; readAt: string }[];
  trend: { takenAt: string; totalUsd: number }[];
}

export interface RpcUsageDto {
  dailyBudget: number;
  today: { job: number; manual: number };
  last30Days: number;
  paused: boolean;
  fullRefreshEstimate: number;
}

export interface SnapshotRunResult {
  read: number;
  failed: number;
  /** Wallets that were due but left for the next run (budget or rate limit). */
  deferred: number;
  stoppedBy: 'budget' | 'rate_limit' | null;
}

type Source = 'job' | 'manual';

/**
 * The holdings monitor (ADMIN_PLAN.md Phase 5).
 *
 * Formation holds nothing: holdings are xStocks in Managers' own wallets,
 * read from chain. Reading every wallet on every page load would spend RPC
 * quota fast, so a background job reads them on a schedule and stores the
 * result, and the dashboard only ever reads what's stored.
 *
 * The job reads the wallets that matter most, most often: Managers seen in
 * the last 7 days every run, others daily, and those idle 30 days or more
 * weekly. It stops for the day when RPC_DAILY_BUDGET is spent, and early when
 * the RPC starts rate limiting; whoever it missed is first in line next run.
 */
@Injectable()
export class AdminHoldingsService implements OnModuleInit {
  private readonly logger = new Logger(AdminHoldingsService.name);
  private running = false;

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(CONFIG) private readonly config: AppConfig,
    @Inject(CLOCK) private readonly clock: Clock,
    @Inject(BALANCE_SOURCE) private readonly balances: BalanceSource,
    @Inject(PRICE_SOURCE) private readonly prices: PriceSource,
    private readonly xstocks: XStocksService,
    private readonly audit: AdminAuditService,
    private readonly scheduler: SchedulerRegistry,
  ) {}

  onModuleInit() {
    const minutes = this.config.walletSnapshotEveryMin;
    if (minutes <= 0) return;
    const interval = setInterval(() => {
      this.runJob('job').catch((e) => this.logger.error(`Wallet snapshot failed: ${String(e)}`));
    }, minutes * MINUTE);
    this.scheduler.addInterval('wallet-snapshot', interval);
  }

  // ── The job ────────────────────────────────────────────────────────────────

  /**
   * Reads the wallets that are due (or [only] these Managers, or everyone when
   * [all]), within today's budget, then writes a platform snapshot.
   */
  async runJob(source: Source, options: { only?: string[]; all?: boolean } = {}): Promise<SnapshotRunResult> {
    if (this.running) return { read: 0, failed: 0, deferred: 0, stoppedBy: null };
    this.running = true;
    try {
      const due = await this.dueWallets(options);
      const remaining = Math.max(0, this.config.rpcDailyBudget - (await this.usedToday()));
      const affordable = Math.floor(remaining / CALLS_PER_WALLET);
      const queue = due.slice(0, affordable);
      let stoppedBy: SnapshotRunResult['stoppedBy'] = due.length > affordable ? 'budget' : null;

      let read = 0;
      let failed = 0;
      const catalogue = await this.xstocks.byMint();
      const batch = Math.max(1, this.config.walletSnapshotBatch);

      for (let i = 0; i < queue.length; i += batch) {
        const chunk = queue.slice(i, i + batch);
        const results = await Promise.all(
          chunk.map((w) =>
            this.balances
              .getBalances(w.wallet, { fresh: true })
              .then((balances) => ({ w, balances, error: null as unknown }))
              .catch((error: unknown) => ({ w, balances: null, error })),
          ),
        );
        await this.spend(source, chunk.length * CALLS_PER_WALLET);

        const ok = results.filter((r) => r.balances !== null);
        failed += results.length - ok.length;
        await this.store(ok.map((r) => ({ userId: r.w.userId, balances: r.balances! })), catalogue);
        read += ok.length;

        if (results.some((r) => r.error && /429|too many requests/i.test(errorText(r.error)))) {
          stoppedBy = 'rate_limit';
          break;
        }
        if (i + batch < queue.length) await new Promise((resolve) => setTimeout(resolve, BATCH_PAUSE_MS));
      }

      await this.snapshot();
      return { read, failed, deferred: due.length - read - failed, stoppedBy };
    } finally {
      this.running = false;
    }
  }

  /** Who's due, least recently read first. */
  private async dueWallets(options: { only?: string[]; all?: boolean }) {
    const now = this.clock.now();
    let q = this.db
      .selectFrom('users')
      .leftJoin('wallet_reads', 'wallet_reads.user_id', 'users.id')
      .select(['users.id as userId', 'users.wallet_address as wallet'])
      .where('users.is_seed', '=', false)
      .where('users.suspended_at', 'is', null)
      .where('users.deleted_at', 'is', null);

    if (options.only) {
      q = q.where('users.id', 'in', options.only.length ? options.only : ['00000000-0000-0000-0000-000000000000']);
    } else if (!options.all) {
      const everyRun = Math.max(1, this.config.walletSnapshotEveryMin) * MINUTE;
      const floor = new Date(now - this.config.walletMinRereadMin * MINUTE);
      const active = new Date(now - 7 * DAY);
      const recent = new Date(now - 30 * DAY);
      q = q.where((eb) =>
        eb.or([
          eb('wallet_reads.read_at', 'is', null),
          eb.and([
            eb('wallet_reads.read_at', '<', floor),
            eb(
              'wallet_reads.read_at',
              '<',
              sql<Date>`${new Date(now)}::timestamptz - case
                when users.last_seen_at >= ${active} then ${`${everyRun} milliseconds`}::interval
                when users.last_seen_at >= ${recent} then interval '1 day'
                else interval '7 days' end`,
            ),
          ]),
        ]),
      );
    }
    return q.orderBy(sql`wallet_reads.read_at asc nulls first`).execute();
  }

  /** Replaces each Manager's stored holdings with what was just read. */
  private async store(
    reads: { userId: string; balances: Map<string, number> }[],
    catalogue: Map<string, unknown>,
  ): Promise<void> {
    if (reads.length === 0) return;
    const mints = new Set<string>();
    for (const r of reads) {
      for (const [mint, amount] of r.balances) if (catalogue.has(mint) && amount > 0) mints.add(mint);
    }
    // Prices come from Jupiter, not the RPC, so they don't count against the budget.
    const priced = mints.size ? await this.prices.getPrices([...mints]) : new Map();
    const readAt = this.clock.date();

    for (const r of reads) {
      const rows = [...r.balances]
        .filter(([mint, amount]) => catalogue.has(mint) && amount > 0)
        .map(([mint, amount]) => {
          const price = priced.get(mint)?.usdPrice;
          return {
            user_id: r.userId,
            mint,
            amount,
            usd_value: price ? Math.round(amount * price * 100) / 100 : null,
            read_at: readAt,
          };
        });
      const total = rows.reduce((sum, row) => sum + (row.usd_value ?? 0), 0);
      await this.db.transaction().execute(async (trx) => {
        await trx.deleteFrom('wallet_holdings').where('user_id', '=', r.userId).execute();
        if (rows.length) await trx.insertInto('wallet_holdings').values(rows).execute();
        await trx
          .insertInto('wallet_reads')
          .values({ user_id: r.userId, read_at: readAt, total_usd: Math.round(total * 100) / 100 })
          .onConflict((oc) =>
            oc.column('user_id').doUpdateSet({ read_at: readAt, total_usd: Math.round(total * 100) / 100 }),
          )
          .execute();
      });
    }
  }

  /** One row summarising what's stored now: the trend line's next point. */
  private async snapshot(): Promise<void> {
    const takenAt = this.clock.date();
    const managers = await this.counted().select((eb) => eb.fn.countAll<string>().as('n')).executeTakeFirstOrThrow();
    const read = await this.counted()
      .innerJoin('wallet_reads', 'wallet_reads.user_id', 'users.id')
      .select((eb) => eb.fn.countAll<string>().as('n'))
      .executeTakeFirstOrThrow();
    const byMint = await this.counted()
      .innerJoin('wallet_holdings', 'wallet_holdings.user_id', 'users.id')
      .select((eb) => [
        'wallet_holdings.mint as mint',
        eb.fn.sum<string>('wallet_holdings.amount').as('amount'),
        eb.fn.sum<string>('wallet_holdings.usd_value').as('usd'),
      ])
      .groupBy('wallet_holdings.mint')
      .execute();

    const mints: Record<string, { amount: number; usd: number | null }> = {};
    let total = 0;
    for (const row of byMint) {
      const usd = row.usd === null ? null : Number(row.usd);
      mints[row.mint] = { amount: Number(row.amount), usd };
      total += usd ?? 0;
    }
    await this.db
      .insertInto('platform_snapshots')
      .values({
        taken_at: takenAt,
        managers: Number(managers.n),
        wallets_read: Number(read.n),
        total_usd: Math.round(total * 100) / 100,
        by_mint: JSON.stringify(mints),
      })
      .onConflict((oc) => oc.column('taken_at').doNothing())
      .execute();
    await this.db
      .deleteFrom('platform_snapshots')
      .where('taken_at', '<', new Date(takenAt.getTime() - SNAPSHOT_KEEP_DAYS * DAY))
      .execute();
  }

  /** Managers whose holdings count: not seeds, not suspended, not deleted. */
  private counted() {
    return this.db
      .selectFrom('users')
      .where('users.is_seed', '=', false)
      .where('users.suspended_at', 'is', null)
      .where('users.deleted_at', 'is', null);
  }

  // ── RPC budget ─────────────────────────────────────────────────────────────

  private today(): string {
    return new Date(this.clock.now()).toISOString().slice(0, 10);
  }

  private async spend(source: Source, calls: number): Promise<void> {
    if (calls <= 0) return;
    await this.db
      .insertInto('rpc_usage')
      .values({ day: sql<Date>`${this.today()}::date`, source, calls })
      .onConflict((oc) =>
        oc.columns(['day', 'source']).doUpdateSet((eb) => ({ calls: eb(eb.ref('rpc_usage.calls'), '+', calls) })),
      )
      .execute();
  }

  private async usedToday(): Promise<number> {
    const row = await this.db
      .selectFrom('rpc_usage')
      .select((eb) => eb.fn.sum<string>('calls').as('n'))
      .where('day', '=', sql<Date>`${this.today()}::date`)
      .executeTakeFirst();
    return Number(row?.n ?? 0);
  }

  async rpcUsage(): Promise<RpcUsageDto> {
    const today = this.today();
    const since = new Date(this.clock.now() - 29 * DAY).toISOString().slice(0, 10);
    const [rows, month, managers] = await Promise.all([
      this.db.selectFrom('rpc_usage').select(['source', 'calls']).where('day', '=', sql<Date>`${today}::date`).execute(),
      this.db
        .selectFrom('rpc_usage')
        .select((eb) => eb.fn.sum<string>('calls').as('n'))
        .where('day', '>=', sql<Date>`${since}::date`)
        .executeTakeFirst(),
      this.counted().select((eb) => eb.fn.countAll<string>().as('n')).executeTakeFirstOrThrow(),
    ]);
    const job = rows.find((r) => r.source === 'job')?.calls ?? 0;
    const manual = rows.find((r) => r.source === 'manual')?.calls ?? 0;
    return {
      dailyBudget: this.config.rpcDailyBudget,
      today: { job, manual },
      last30Days: Number(month?.n ?? 0),
      paused: job + manual >= this.config.rpcDailyBudget,
      fullRefreshEstimate: Number(managers.n) * CALLS_PER_WALLET,
    };
  }

  // ── Dashboard reads ────────────────────────────────────────────────────────

  async overview(): Promise<HoldingsOverviewDto> {
    const now = this.clock.now();
    const everyRun = Math.max(1, this.config.walletSnapshotEveryMin) * MINUTE;

    const [totals, reads, stocks, top, trend, latest] = await Promise.all([
      this.counted().select((eb) => eb.fn.countAll<string>().as('managers')).executeTakeFirstOrThrow(),
      this.counted()
        .innerJoin('wallet_reads', 'wallet_reads.user_id', 'users.id')
        .select((eb) => [
          eb.fn.countAll<string>().as('read'),
          eb.fn.countAll<string>().filterWhere('wallet_reads.total_usd', '>', 0).as('holders'),
          // Older than twice what their tier allows: missed at least one turn.
          eb.fn
            .countAll<string>()
            .filterWhere(
              sql<boolean>`wallet_reads.read_at < ${new Date(now)}::timestamptz - 2 * case
                when users.last_seen_at >= ${new Date(now - 7 * DAY)} then ${`${everyRun} milliseconds`}::interval
                when users.last_seen_at >= ${new Date(now - 30 * DAY)} then interval '1 day'
                else interval '7 days' end`,
            )
            .as('stale'),
        ])
        .executeTakeFirstOrThrow(),
      this.counted()
        .innerJoin('wallet_holdings', 'wallet_holdings.user_id', 'users.id')
        .leftJoin('xstocks', 'xstocks.mint', 'wallet_holdings.mint')
        .select((eb) => [
          'wallet_holdings.mint as mint',
          eb.fn.max('xstocks.symbol').as('symbol'),
          eb.fn.sum<string>('wallet_holdings.amount').as('amount'),
          eb.fn.sum<string>('wallet_holdings.usd_value').as('usd'),
          eb.fn.count<string>('wallet_holdings.user_id').distinct().as('holders'),
          eb.fn
            .sum<string>('wallet_holdings.usd_value')
            .filterWhere(
              sql<boolean>`exists (
                select 1 from rosters r join roster_slots s on s.roster_id = r.id
                where r.user_id = wallet_holdings.user_id and s.token_mint = wallet_holdings.mint)`,
            )
            .as('drafted'),
        ])
        .groupBy('wallet_holdings.mint')
        .execute(),
      this.counted()
        .innerJoin('wallet_reads', 'wallet_reads.user_id', 'users.id')
        .select([
          'users.id as id',
          'users.username as username',
          'users.wallet_address as wallet',
          'wallet_reads.total_usd as usd',
          'wallet_reads.read_at as read_at',
        ])
        .where('wallet_reads.total_usd', '>', 0)
        .orderBy('wallet_reads.total_usd', 'desc')
        .limit(20)
        .execute(),
      // The day's last snapshot, for each of the last 30 days.
      sql<{ taken_at: Date; total_usd: string }>`
        select distinct on (date_trunc('day', taken_at)) taken_at, total_usd
        from platform_snapshots
        where taken_at >= ${new Date(now - 30 * DAY)}
        order by date_trunc('day', taken_at), taken_at desc
      `.execute(this.db),
      this.db.selectFrom('platform_snapshots').select((eb) => eb.fn.max('taken_at').as('at')).executeTakeFirst(),
    ]);

    const byStock: StockHoldingDto[] = stocks
      .map((s) => ({
        mint: s.mint,
        symbol: (s.symbol as string | null) ?? `${s.mint.slice(0, 4)}…`,
        amount: Number(s.amount),
        usdValue: s.usd === null ? null : Number(s.usd),
        holders: Number(s.holders),
        draftedUsd: Number(s.drafted ?? 0),
      }))
      .sort((a, b) => (b.usdValue ?? -1) - (a.usdValue ?? -1));

    return {
      totalUsd: round(byStock.reduce((sum, s) => sum + (s.usdValue ?? 0), 0)),
      draftedUsd: round(byStock.reduce((sum, s) => sum + s.draftedUsd, 0)),
      walletsRead: Number(reads.read),
      walletsTotal: Number(totals.managers),
      walletsStale: Number(reads.stale),
      holders: Number(reads.holders),
      snapshotTakenAt: latest?.at ? new Date(latest.at as Date).toISOString() : null,
      byStock,
      topHolders: top.map((t) => ({
        id: t.id,
        username: t.username,
        walletAddress: t.wallet,
        usdValue: Number(t.usd),
        readAt: new Date(t.read_at).toISOString(),
      })),
      trend: trend.rows.map((r) => ({
        takenAt: new Date(r.taken_at).toISOString(),
        totalUsd: Number(r.total_usd),
      })),
    };
  }

  /** One Manager's stored holdings, for their admin page. */
  async holdingsOf(userId: string) {
    const [read, rows] = await Promise.all([
      this.db.selectFrom('wallet_reads').selectAll().where('user_id', '=', userId).executeTakeFirst(),
      this.db
        .selectFrom('wallet_holdings')
        .leftJoin('xstocks', 'xstocks.mint', 'wallet_holdings.mint')
        .select([
          'wallet_holdings.mint as mint',
          'xstocks.symbol as symbol',
          'wallet_holdings.amount as amount',
          'wallet_holdings.usd_value as usd',
        ])
        .where('wallet_holdings.user_id', '=', userId)
        .orderBy('wallet_holdings.usd_value', 'desc')
        .execute(),
    ]);
    return {
      readAt: read ? new Date(read.read_at).toISOString() : null,
      totalUsd: read ? Number(read.total_usd) : null,
      positions: rows.map((r) => ({
        mint: r.mint,
        symbol: r.symbol ?? `${r.mint.slice(0, 4)}…`,
        amount: Number(r.amount),
        usdValue: r.usd === null ? null : Number(r.usd),
      })),
    };
  }

  // ── Manual refresh ─────────────────────────────────────────────────────────

  /**
   * Re-reads one wallet now, or starts a read of every wallet in the
   * background. Audited; at most once per five minutes for each.
   */
  async refresh(
    admin: string,
    input: { userId?: string; reason: string },
  ): Promise<{ started: boolean; wallets: number; result?: SnapshotRunResult; action: AdminActionDto }> {
    const now = this.clock.now();
    const usage = await this.rpcUsage();
    if (usage.paused) {
      throw new HttpException("Today's RPC budget is spent; reads resume tomorrow (UTC)", HttpStatus.TOO_MANY_REQUESTS);
    }

    if (input.userId) {
      const user = await this.db
        .selectFrom('users')
        .leftJoin('wallet_reads', 'wallet_reads.user_id', 'users.id')
        .select(['users.id', 'users.is_seed', 'users.deleted_at', 'wallet_reads.read_at'])
        .where('users.id', '=', input.userId)
        .executeTakeFirst()
        .catch(() => undefined);
      if (!user || user.deleted_at) throw new NotFoundException('No such Manager');
      if (user.read_at && now - new Date(user.read_at).getTime() < REFRESH_COOLDOWN_MS) {
        throw new HttpException('This wallet was read in the last 5 minutes', HttpStatus.TOO_MANY_REQUESTS);
      }
      const { action } = await this.audit.run(
        { admin, action: 'holdings.refresh', targetUserId: input.userId, reason: input.reason },
        async () => ({ result: null, detail: { calls: CALLS_PER_WALLET } }),
      );
      const result = await this.runJob('manual', { only: [input.userId] });
      return { started: true, wallets: 1, result, action };
    }

    const recent = await this.db
      .selectFrom('admin_actions')
      .select('id')
      .where('action', '=', 'holdings.refresh_all')
      .where('created_at', '>', new Date(now - REFRESH_COOLDOWN_MS))
      .executeTakeFirst();
    if (recent || this.running) {
      throw new HttpException('A full refresh ran in the last 5 minutes', HttpStatus.TOO_MANY_REQUESTS);
    }
    const wallets = usage.fullRefreshEstimate / CALLS_PER_WALLET;
    const { action } = await this.audit.run(
      { admin, action: 'holdings.refresh_all', reason: input.reason },
      async () => ({ result: null, detail: { wallets, estimatedCalls: usage.fullRefreshEstimate } }),
    );
    // Long: return straight away; the page reloads to see it land.
    this.runJob('manual', { all: true }).catch((e) => this.logger.error(`Full refresh failed: ${String(e)}`));
    return { started: true, wallets, action };
  }
}

const round = (n: number) => Math.round(n * 100) / 100;

const errorText = (e: unknown) => (e instanceof Error ? e.message : typeof e === 'string' ? e : JSON.stringify(e));

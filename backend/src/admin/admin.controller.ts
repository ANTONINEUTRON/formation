import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Res,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { AdminUserGuard, CurrentAdmin } from '../auth/auth.guard.js';
import { FeedbackService } from '../feedback/feedback.service.js';
import type { FeedbackItemDto } from '../feedback/feedback.service.js';
import { AdminAssistantService } from './assistant-admin.service.js';
import { AdminAuditService, requireReason } from './audit.service.js';
import { AdminHealthService } from './health.service.js';
import { AdminHoldingsService } from './holdings.service.js';
import { AdminManagersService } from './managers-admin.service.js';
import type { ManagersQuery } from './managers-admin.service.js';
import { AdminOpsService } from './ops.service.js';

type ReasonBody = { reason?: unknown };

/**
 * The admin API (ADMIN_PLAN.md). Everything needs AdminUserGuard: a session
 * for a wallet in ADMIN_WALLETS, or the x-admin-key header for scripts. Every
 * write takes a reason and is recorded in the audit log.
 */
@Controller('admin')
@UseGuards(AdminUserGuard)
export class AdminController {
  constructor(
    private readonly feedback: FeedbackService,
    private readonly audit: AdminAuditService,
    private readonly healthChecks: AdminHealthService,
    private readonly managers: AdminManagersService,
    private readonly holdings: AdminHoldingsService,
    private readonly assistant: AdminAssistantService,
    private readonly ops: AdminOpsService,
  ) {}

  /** The admin app calls this after sign-in; anyone else got a 403 from the guard. */
  @Get('me')
  me(@CurrentAdmin() admin: string) {
    return { admin: true, as: admin };
  }

  @Get('health')
  health() {
    return this.healthChecks.health();
  }

  /** Newest first: ?admin=&action=&userId=&before=&limit= */
  @Get('actions')
  actions(@Query() query: Record<string, string>) {
    return this.audit.list(query);
  }

  // ── Operations ──────────────────────────────────────────────────────────

  /** Re-reads the xStocks catalogue from Jupiter without waiting for the timer. */
  @Post('catalogue/refresh')
  refreshCatalogue(@CurrentAdmin() admin: string, @Body() body: ReasonBody) {
    return this.ops.run(admin, 'catalogue.refresh', this.ops.reasonFor(admin, body?.reason));
  }

  /** Records prices now and banks everything owed since the last tick. */
  @Post('tick')
  tick(@CurrentAdmin() admin: string, @Body() body: ReasonBody) {
    return this.ops.run(admin, 'scoring.tick', this.ops.reasonFor(admin, body?.reason));
  }

  /** Opens scheduled leagues and settles finished ones without waiting. */
  @Post('leagues/process')
  processLeagues(@CurrentAdmin() admin: string, @Body() body: ReasonBody) {
    return this.ops.run(admin, 'leagues.process', this.ops.reasonFor(admin, body?.reason));
  }

  @Post('leagues/:id/settle')
  settle(@CurrentAdmin() admin: string, @Param('id') id: string, @Body() body: ReasonBody) {
    return this.ops.run(admin, 'leagues.settle', this.ops.reasonFor(admin, body?.reason), id);
  }

  @Get('leagues')
  leagues() {
    return this.ops.leaguesList();
  }

  @Get('ops/status')
  opsStatus() {
    return this.ops.statuses();
  }

  // ── Managers ────────────────────────────────────────────────────────────

  /** The searchable, filterable list. Database only; never the RPC. */
  @Get('platform/users')
  users(@Query() query: ManagersQuery) {
    return this.managers.list(query);
  }

  @Get('managers/:id')
  manager(@Param('id') id: string) {
    return this.managers.detail(id);
  }

  @Post('managers/:id/username/reset')
  resetUsername(@CurrentAdmin() admin: string, @Param('id') id: string, @Body() body: ReasonBody) {
    return this.managers.resetUsername(admin, id, requireReason(body?.reason));
  }

  @Post('managers/:id/bio/clear')
  clearBio(@CurrentAdmin() admin: string, @Param('id') id: string, @Body() body: ReasonBody) {
    return this.managers.clearBio(admin, id, requireReason(body?.reason));
  }

  @Post('managers/:id/avatar/delete')
  deleteAvatar(@CurrentAdmin() admin: string, @Param('id') id: string, @Body() body: ReasonBody) {
    return this.managers.deleteAvatar(admin, id, requireReason(body?.reason));
  }

  @Post('managers/:id/suspend')
  suspend(@CurrentAdmin() admin: string, @Param('id') id: string, @Body() body: ReasonBody) {
    return this.managers.suspend(admin, id, requireReason(body?.reason));
  }

  @Post('managers/:id/unsuspend')
  unsuspend(@CurrentAdmin() admin: string, @Param('id') id: string, @Body() body: ReasonBody) {
    return this.managers.unsuspend(admin, id, requireReason(body?.reason));
  }

  /** { mode, points, reason, confirmLarge? } */
  @Post('managers/:id/corrections')
  correct(
    @CurrentAdmin() admin: string,
    @Param('id') id: string,
    @Body() body: { mode?: unknown; points?: unknown; reason?: unknown; confirmLarge?: unknown },
  ) {
    return this.managers.correct(admin, id, { ...body, reason: requireReason(body?.reason) });
  }

  /** { credits, reason }: positive grants, negative claws back. */
  @Post('managers/:id/credits')
  credits(
    @CurrentAdmin() admin: string,
    @Param('id') id: string,
    @Body() body: { credits?: unknown; reason?: unknown },
  ) {
    return this.managers.adjustCredits(admin, id, { ...body, reason: requireReason(body?.reason) });
  }

  @Get('managers/:id/quotes')
  quotes(@Param('id') id: string) {
    return this.assistant.quotesFor(id);
  }

  /** { reason, confirmUsername }: anonymises the account. */
  @Delete('managers/:id')
  deleteManager(
    @CurrentAdmin() admin: string,
    @Param('id') id: string,
    @Body() body: { reason?: unknown; confirmUsername?: unknown },
  ) {
    return this.managers.deleteAccount(admin, id, { ...body, reason: requireReason(body?.reason) });
  }

  // ── Holdings ────────────────────────────────────────────────────────────

  @Get('platform/assets')
  assets() {
    return this.holdings.overview();
  }

  @Get('platform/rpc-usage')
  rpcUsage() {
    return this.holdings.rpcUsage();
  }

  /** { userId?, reason }: one wallet now, or every wallet in the background. */
  @Post('platform/assets/refresh')
  refreshAssets(@CurrentAdmin() admin: string, @Body() body: { userId?: unknown; reason?: unknown }) {
    return this.holdings.refresh(admin, {
      userId: typeof body?.userId === 'string' && body.userId ? body.userId : undefined,
      reason: requireReason(body?.reason),
    });
  }

  // ── Assistant Manager ───────────────────────────────────────────────────

  @Get('assistant')
  assistantOverview() {
    return this.assistant.overview();
  }

  @Get('assistant/purchases/:signature')
  purchase(@Param('signature') signature: string) {
    return this.assistant.purchase(signature);
  }

  // ── Feedback ────────────────────────────────────────────────────────────

  /** Newest first: ?status=new|read|done&limit=50. Screenshots by their own URL. */
  @Get('feedback')
  listFeedback(@Query() query: { status?: string; limit?: string }): Promise<FeedbackItemDto[]> {
    return this.feedback.list(query);
  }

  @Get('feedback/:id/screenshot')
  async feedbackScreenshot(
    @Param('id') id: string,
    @Res({ passthrough: true }) res: { setHeader(name: string, value: string): void },
  ): Promise<StreamableFile> {
    const image = await this.feedback.screenshot(id);
    res.setHeader('Content-Type', image.mime);
    return new StreamableFile(image.data);
  }

  /** Marks feedback read or done: { "status": "done" }. */
  @Patch('feedback/:id')
  setFeedbackStatus(@Param('id') id: string, @Body() body: { status?: unknown }) {
    return this.feedback.setStatus(id, body?.status);
  }
}

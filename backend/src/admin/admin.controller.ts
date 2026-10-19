import { Body, Controller, Get, Param, Patch, Post, Query, Res, StreamableFile, UseGuards } from '@nestjs/common';
import { AdminGuard } from '../auth/auth.guard.js';
import { FeedbackService } from '../feedback/feedback.service.js';
import type { FeedbackItemDto } from '../feedback/feedback.service.js';
import { LeaguesService } from '../leagues/leagues.service.js';
import { PriceTickService } from '../scoring/price-tick.service.js';
import { XStocksCatalogueService } from '../xstocks/xstocks-catalogue.service.js';

/** Demo controls so scoring can be driven on stage, and the feedback inbox. */
@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(
    private readonly priceTicks: PriceTickService,
    private readonly leagues: LeaguesService,
    private readonly catalogue: XStocksCatalogueService,
    private readonly feedback: FeedbackService,
  ) {}

  /** Re-reads the xStocks catalogue from Jupiter without waiting for the timer. */
  @Post('catalogue/refresh')
  refreshCatalogue() {
    return this.catalogue.refresh();
  }

  /** Records prices now and banks everything owed since the last tick. */
  @Post('tick')
  tick() {
    return this.priceTicks.tick();
  }

  /** Opens scheduled leagues and settles finished ones without waiting. */
  @Post('leagues/process')
  processLeagues() {
    return this.leagues.processDue();
  }

  @Post('leagues/:id/settle')
  async settle(@Param('id') id: string) {
    await this.leagues.settleById(id);
    return { settled: id };
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

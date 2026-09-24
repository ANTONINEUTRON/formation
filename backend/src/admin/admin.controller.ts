import { Controller, Param, Post, UseGuards } from '@nestjs/common';
import { AdminGuard } from '../auth/auth.guard.js';
import { LeaguesService } from '../leagues/leagues.service.js';
import { PriceTickService } from '../scoring/price-tick.service.js';

/** Demo controls so scoring can be driven on stage. */
@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(
    private readonly priceTicks: PriceTickService,
    private readonly leagues: LeaguesService,
  ) {}

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
}

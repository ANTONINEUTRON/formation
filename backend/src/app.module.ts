import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { CoreModule } from './core/core.module.js';
import {
  AdminController,
  DuelController,
  TrophyController,
} from './duel/duel.controller.js';
import { DuelService } from './duel/duel.service.js';
import { LeagueController } from './league/league.controller.js';
import { LeagueService } from './league/league.service.js';
import { RosterController, WalletController } from './roster/roster.controller.js';
import { RosterService } from './roster/roster.service.js';
import { ScoringService } from './scoring/scoring.service.js';
import { SwapController } from './swap/swap.controller.js';
import { SwapService } from './swap/swap.service.js';
import { TrophyService } from './trophy/trophy.service.js';
import { XStocksController } from './xstocks/xstocks.controller.js';

@Module({
  imports: [ScheduleModule.forRoot(), CoreModule, AuthModule],
  controllers: [
    AppController,
    XStocksController,
    LeagueController,
    RosterController,
    WalletController,
    DuelController,
    TrophyController,
    SwapController,
    AdminController,
  ],
  providers: [
    AppService,
    LeagueService,
    RosterService,
    ScoringService,
    TrophyService,
    DuelService,
    SwapService,
  ],
})
export class AppModule {}

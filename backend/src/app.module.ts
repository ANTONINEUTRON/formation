import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AdminController } from './admin/admin.controller.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { CoreModule } from './core/core.module.js';
import { LeagueController } from './league/league.controller.js';
import { LeagueService } from './league/league.service.js';
import { LeaguesController } from './leagues/leagues.controller.js';
import { LeaguesService } from './leagues/leagues.service.js';
import { ManagersController } from './managers/managers.controller.js';
import { ManagersService } from './managers/managers.service.js';
import { NotificationsController } from './notifications/notifications.controller.js';
import { NotificationsService } from './notifications/notifications.service.js';
import { RosterController, WalletController } from './roster/roster.controller.js';
import { RosterService } from './roster/roster.service.js';
import { EntryScoringService } from './scoring/entry-scoring.service.js';
import { GeneralScoringService } from './scoring/general-scoring.service.js';
import { PriceTickService } from './scoring/price-tick.service.js';
import { SwapController } from './swap/swap.controller.js';
import { UsersController } from './users/users.controller.js';
import { UsersService } from './users/users.service.js';
import { SwapService } from './swap/swap.service.js';
import { XStocksController } from './xstocks/xstocks.controller.js';

@Module({
  imports: [ScheduleModule.forRoot(), CoreModule, AuthModule],
  controllers: [
    AppController,
    XStocksController,
    // The always-on general league.
    LeagueController,
    // Custom leagues and PvP duels, which are the same object.
    LeaguesController,
    RosterController,
    WalletController,
    NotificationsController,
    ManagersController,
    UsersController,
    SwapController,
    AdminController,
  ],
  providers: [
    AppService,
    EntryScoringService,
    GeneralScoringService,
    PriceTickService,
    LeagueService,
    LeaguesService,
    NotificationsService,
    ManagersService,
    RosterService,
    UsersService,
    SwapService,
  ],
})
export class AppModule {}

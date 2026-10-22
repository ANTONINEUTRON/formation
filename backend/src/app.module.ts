import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AdminController } from './admin/admin.controller.js';
import { AdminAssistantService } from './admin/assistant-admin.service.js';
import { AdminAuditService } from './admin/audit.service.js';
import { AdminHealthService } from './admin/health.service.js';
import { AdminHoldingsService } from './admin/holdings.service.js';
import { AdminManagersService } from './admin/managers-admin.service.js';
import { AdminOpsService } from './admin/ops.service.js';
import { FeedbackController } from './feedback/feedback.controller.js';
import { FeedbackService } from './feedback/feedback.service.js';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AssistantController } from './assistant/assistant.controller.js';
import { AssistantService } from './assistant/assistant.service.js';
import { CardsService } from './assistant/cards.js';
import { StarterService } from './assistant/starter.js';
import { AvatarService } from './assistant/avatars.js';
import { CreditsService } from './assistant/credits.service.js';
import { GeminiProvider } from './assistant/gemini.provider.js';
import { LLM_PROVIDER } from './assistant/llm.js';
import { PurchasesService } from './assistant/purchases.service.js';
import { SKR_PAYMENTS, SolanaSkrPayments } from './assistant/skr-payments.js';
import { AuthModule } from './auth/auth.module.js';
import { CoreModule } from './core/core.module.js';
import { LeagueController } from './league/league.controller.js';
import { LeagueService } from './league/league.service.js';
import { LeaguesController } from './leagues/leagues.controller.js';
import { LeaguesService } from './leagues/leagues.service.js';
import { ManagersController } from './managers/managers.controller.js';
import { ManagersService } from './managers/managers.service.js';
import { NotificationsController } from './notifications/notifications.controller.js';
import { CONFIG } from './core/config.js';
import type { AppConfig } from './core/config.js';
import { FcmPushSender, parseServiceAccount, PUSH_SENDER } from './notifications/fcm.js';
import { NotificationsService } from './notifications/notifications.service.js';
import { PushService } from './notifications/push.service.js';
import { OgController, OgRateLimitGuard } from './og/og.controller.js';
import { OgService } from './og/og.service.js';
import { RosterController, WalletController } from './roster/roster.controller.js';
import { RosterService } from './roster/roster.service.js';
import { EntryScoringService } from './scoring/entry-scoring.service.js';
import { GeneralScoringService } from './scoring/general-scoring.service.js';
import { MatchWeekController } from './scoring/match-week.controller.js';
import { MatchWeekService } from './scoring/match-week.service.js';
import { PriceTickService } from './scoring/price-tick.service.js';
import { SeasonService } from './scoring/season.service.js';
import { SkillService } from './scoring/skill.service.js';
import { LedgerService } from './scoring/ledger.service.js';
import { PortfolioService } from './scoring/portfolio.service.js';
import { SwapController } from './swap/swap.controller.js';
import { UsersController } from './users/users.controller.js';
import { UsersService } from './users/users.service.js';
import { StreakService } from './users/streak.service.js';
import { SwapService } from './swap/swap.service.js';
import { XStocksCatalogueService } from './xstocks/xstocks-catalogue.service.js';
import { XStocksController } from './xstocks/xstocks.controller.js';
import { TiersService } from './xstocks/tiers.service.js';

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
    AssistantController,
    MatchWeekController,
    // Unauthenticated share previews, read by the ogRender function.
    OgController,
    AdminController,
    FeedbackController,
  ],
  providers: [
    AppService,
    SeasonService,
    SkillService,
    LedgerService,
    PortfolioService,
    MatchWeekService,
    EntryScoringService,
    GeneralScoringService,
    PriceTickService,
    LeagueService,
    LeaguesService,
    NotificationsService,
    ManagersService,
    OgService,
    OgRateLimitGuard,
    RosterService,
    UsersService,
    StreakService,
    SwapService,
    XStocksCatalogueService,
    TiersService,
    AssistantService,
    CreditsService,
    PurchasesService,
    CardsService,
    StarterService,
    AvatarService,
    PushService,
    FeedbackService,
    AdminAuditService,
    AdminHealthService,
    AdminHoldingsService,
    AdminManagersService,
    AdminAssistantService,
    AdminOpsService,
    // Swapped for fakes in tests.
    { provide: LLM_PROVIDER, useClass: GeminiProvider },
    { provide: SKR_PAYMENTS, useClass: SolanaSkrPayments },
    {
      provide: PUSH_SENDER,
      useFactory: (config: AppConfig) => new FcmPushSender(parseServiceAccount(config.fcmServiceAccount)),
      inject: [CONFIG],
    },
  ],
})
export class AppModule {}

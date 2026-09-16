import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/features/draft/ui/pages/draft_board_page.dart';
import 'package:symbians/features/duel/ui/pages/create_duel_page.dart';
import 'package:symbians/features/duel/ui/pages/duel_detail_page.dart';
import 'package:symbians/features/home/ui/pages/home_page.dart';
import 'package:symbians/features/notifications/ui/pages/notifications_page.dart';
import 'package:symbians/features/profile/ui/pages/profile_page.dart';
import 'package:symbians/features/profile/ui/pages/transaction_history_page.dart';
import 'package:symbians/features/reports/ui/pages/reports_page.dart';
import 'package:symbians/features/shared/domain/models.dart';

part 'app_route.gr.dart';

/// Application router configuration using auto_route.
///
/// After modifying routes, run:
/// ```
/// dart run build_runner build --delete-conflicting-outputs
/// ```
@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        // Home (one nav bar tab per sport)
        AutoRoute(page: HomeRoute.page, path: '/', initial: true),

        // Draft a roster for one sport mode
        AutoRoute(page: DraftBoardRoute.page, path: '/draft'),

        // Duels
        AutoRoute(page: CreateDuelRoute.page, path: '/duels/new'),
        AutoRoute(page: DuelDetailRoute.page, path: '/duels/:duelId'),

        // App bar destinations
        AutoRoute(page: ProfileRoute.page, path: '/profile'),
        AutoRoute(page: ReportsRoute.page, path: '/reports'),
        AutoRoute(page: NotificationsRoute.page, path: '/notifications'),

        // Transaction History
        AutoRoute(page: TransactionHistoryRoute.page, path: '/transactions'),
      ];

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();
}

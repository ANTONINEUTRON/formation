import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:formation/features/draft/ui/pages/draft_board_page.dart';
import 'package:formation/features/leagues/ui/pages/league_detail_page.dart';
import 'package:formation/features/managers/ui/pages/manager_profile_page.dart';
import 'package:formation/features/leagues/ui/pages/leagues_page.dart';
import 'package:formation/features/home/ui/pages/home_page.dart';
import 'package:formation/features/notifications/ui/pages/notifications_page.dart';
import 'package:formation/features/profile/ui/pages/profile_page.dart';
import 'package:formation/features/profile/ui/pages/transaction_history_page.dart';
import 'package:formation/features/reports/ui/pages/reports_page.dart';
import 'package:formation/features/shared/domain/models.dart';

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

        // Another player's profile, lineup and wallet
        AutoRoute(page: ManagerProfileRoute.page, path: '/managers/:userId'),

        // Custom leagues (a PvP duel is a two-player private league)
        AutoRoute(page: LeaguesRoute.page, path: '/leagues'),
        AutoRoute(page: LeagueDetailRoute.page, path: '/leagues/:leagueId'),

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

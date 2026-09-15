import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:symbians/features/home/ui/pages/home_page.dart';
import 'package:symbians/features/profile/ui/pages/transaction_history_page.dart';
import 'package:symbians/features/reports/ui/pages/reports_page.dart';
import 'package:symbians/features/strategy/ui/pages/strategy_marketplace_page.dart';
import 'package:symbians/features/agent/ui/pages/agent_type_selector_page.dart';
import 'package:symbians/features/agent/ui/pages/create_agent_page.dart';
import 'package:symbians/features/agent/ui/pages/agent_chat_page.dart';
import 'package:symbians/features/agent/ui/pages/agent_config_page.dart';
import 'package:symbians/features/notifications/ui/pages/notifications_page.dart';

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
        // Home (main shell with tabs)
        AutoRoute(
          page: HomeRoute.page,
          path: '/',
          initial: true,
        ),
        // Transaction History
        AutoRoute(
          page: TransactionHistoryRoute.page,
          path: '/transactions',
        ),

        // Reports
        AutoRoute(
          page: ReportsRoute.page,
          path: '/reports',
        ),

        // Strategy Marketplace
        AutoRoute(
          page: StrategyMarketplaceRoute.page,
          path: '/marketplace',
        ),

        // Agent Type Selector
        AutoRoute(
          page: AgentTypeSelectorRoute.page,
          path: '/agent/new',
        ),

        // Create Agent
        AutoRoute(
          page: CreateAgentRoute.page,
          path: '/agent/create',
        ),

        // Agent Chat
        AutoRoute(
          page: AgentChatRoute.page,
          path: '/agent/:agentId/chat',
        ),

        // Agent Config
        AutoRoute(
          page: AgentConfigRoute.page,
          path: '/agent/:agentId/config',
        ),

        // Notifications
        AutoRoute(
          page: NotificationsRoute.page,
          path: '/notifications',
        ),
      ];

  @override
  RouteType get defaultRouteType => const RouteType.adaptive();
}

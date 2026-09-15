// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_route.dart';

/// generated route for
/// [AgentChatPage]
class AgentChatRoute extends PageRouteInfo<AgentChatRouteArgs> {
  AgentChatRoute({
    Key? key,
    required String agentId,
    required String agentName,
    List<PageRouteInfo>? children,
  }) : super(
         AgentChatRoute.name,
         args: AgentChatRouteArgs(
           key: key,
           agentId: agentId,
           agentName: agentName,
         ),
         initialChildren: children,
       );

  static const String name = 'AgentChatRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AgentChatRouteArgs>();
      return AgentChatPage(
        key: args.key,
        agentId: args.agentId,
        agentName: args.agentName,
      );
    },
  );
}

class AgentChatRouteArgs {
  const AgentChatRouteArgs({
    this.key,
    required this.agentId,
    required this.agentName,
  });

  final Key? key;

  final String agentId;

  final String agentName;

  @override
  String toString() {
    return 'AgentChatRouteArgs{key: $key, agentId: $agentId, agentName: $agentName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AgentChatRouteArgs) return false;
    return key == other.key &&
        agentId == other.agentId &&
        agentName == other.agentName;
  }

  @override
  int get hashCode => key.hashCode ^ agentId.hashCode ^ agentName.hashCode;
}

/// generated route for
/// [AgentConfigPage]
class AgentConfigRoute extends PageRouteInfo<AgentConfigRouteArgs> {
  AgentConfigRoute({
    Key? key,
    required String agentId,
    required String agentName,
    List<PageRouteInfo>? children,
  }) : super(
         AgentConfigRoute.name,
         args: AgentConfigRouteArgs(
           key: key,
           agentId: agentId,
           agentName: agentName,
         ),
         initialChildren: children,
       );

  static const String name = 'AgentConfigRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AgentConfigRouteArgs>();
      return AgentConfigPage(
        key: args.key,
        agentId: args.agentId,
        agentName: args.agentName,
      );
    },
  );
}

class AgentConfigRouteArgs {
  const AgentConfigRouteArgs({
    this.key,
    required this.agentId,
    required this.agentName,
  });

  final Key? key;

  final String agentId;

  final String agentName;

  @override
  String toString() {
    return 'AgentConfigRouteArgs{key: $key, agentId: $agentId, agentName: $agentName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AgentConfigRouteArgs) return false;
    return key == other.key &&
        agentId == other.agentId &&
        agentName == other.agentName;
  }

  @override
  int get hashCode => key.hashCode ^ agentId.hashCode ^ agentName.hashCode;
}

/// generated route for
/// [AgentTypeSelectorPage]
class AgentTypeSelectorRoute extends PageRouteInfo<void> {
  const AgentTypeSelectorRoute({List<PageRouteInfo>? children})
    : super(AgentTypeSelectorRoute.name, initialChildren: children);

  static const String name = 'AgentTypeSelectorRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AgentTypeSelectorPage();
    },
  );
}

/// generated route for
/// [CreateAgentPage]
class CreateAgentRoute extends PageRouteInfo<void> {
  const CreateAgentRoute({List<PageRouteInfo>? children})
    : super(CreateAgentRoute.name, initialChildren: children);

  static const String name = 'CreateAgentRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CreateAgentPage();
    },
  );
}

/// generated route for
/// [HomePage]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomePage();
    },
  );
}

/// generated route for
/// [NotificationsPage]
class NotificationsRoute extends PageRouteInfo<void> {
  const NotificationsRoute({List<PageRouteInfo>? children})
    : super(NotificationsRoute.name, initialChildren: children);

  static const String name = 'NotificationsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const NotificationsPage();
    },
  );
}

/// generated route for
/// [ReportsPage]
class ReportsRoute extends PageRouteInfo<void> {
  const ReportsRoute({List<PageRouteInfo>? children})
    : super(ReportsRoute.name, initialChildren: children);

  static const String name = 'ReportsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ReportsPage();
    },
  );
}

/// generated route for
/// [StrategyMarketplacePage]
class StrategyMarketplaceRoute extends PageRouteInfo<void> {
  const StrategyMarketplaceRoute({List<PageRouteInfo>? children})
    : super(StrategyMarketplaceRoute.name, initialChildren: children);

  static const String name = 'StrategyMarketplaceRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const StrategyMarketplacePage();
    },
  );
}

/// generated route for
/// [TransactionHistoryPage]
class TransactionHistoryRoute extends PageRouteInfo<void> {
  const TransactionHistoryRoute({List<PageRouteInfo>? children})
    : super(TransactionHistoryRoute.name, initialChildren: children);

  static const String name = 'TransactionHistoryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const TransactionHistoryPage();
    },
  );
}

// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_route.dart';

/// generated route for
/// [DraftBoardPage]
class DraftBoardRoute extends PageRouteInfo<DraftBoardRouteArgs> {
  DraftBoardRoute({
    required SportMode mode,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         DraftBoardRoute.name,
         args: DraftBoardRouteArgs(mode: mode, key: key),
         initialChildren: children,
       );

  static const String name = 'DraftBoardRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DraftBoardRouteArgs>();
      return DraftBoardPage(mode: args.mode, key: args.key);
    },
  );
}

class DraftBoardRouteArgs {
  const DraftBoardRouteArgs({required this.mode, this.key});

  final SportMode mode;

  final Key? key;

  @override
  String toString() {
    return 'DraftBoardRouteArgs{mode: $mode, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DraftBoardRouteArgs) return false;
    return mode == other.mode && key == other.key;
  }

  @override
  int get hashCode => mode.hashCode ^ key.hashCode;
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
/// [LeagueDetailPage]
class LeagueDetailRoute extends PageRouteInfo<LeagueDetailRouteArgs> {
  LeagueDetailRoute({
    required String leagueId,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         LeagueDetailRoute.name,
         args: LeagueDetailRouteArgs(leagueId: leagueId, key: key),
         initialChildren: children,
       );

  static const String name = 'LeagueDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LeagueDetailRouteArgs>();
      return LeagueDetailPage(leagueId: args.leagueId, key: args.key);
    },
  );
}

class LeagueDetailRouteArgs {
  const LeagueDetailRouteArgs({required this.leagueId, this.key});

  final String leagueId;

  final Key? key;

  @override
  String toString() {
    return 'LeagueDetailRouteArgs{leagueId: $leagueId, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LeagueDetailRouteArgs) return false;
    return leagueId == other.leagueId && key == other.key;
  }

  @override
  int get hashCode => leagueId.hashCode ^ key.hashCode;
}

/// generated route for
/// [LeaguesPage]
class LeaguesRoute extends PageRouteInfo<LeaguesRouteArgs> {
  LeaguesRoute({
    required SportMode mode,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         LeaguesRoute.name,
         args: LeaguesRouteArgs(mode: mode, key: key),
         initialChildren: children,
       );

  static const String name = 'LeaguesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LeaguesRouteArgs>();
      return LeaguesPage(mode: args.mode, key: args.key);
    },
  );
}

class LeaguesRouteArgs {
  const LeaguesRouteArgs({required this.mode, this.key});

  final SportMode mode;

  final Key? key;

  @override
  String toString() {
    return 'LeaguesRouteArgs{mode: $mode, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LeaguesRouteArgs) return false;
    return mode == other.mode && key == other.key;
  }

  @override
  int get hashCode => mode.hashCode ^ key.hashCode;
}

/// generated route for
/// [ManagerProfilePage]
class ManagerProfileRoute extends PageRouteInfo<ManagerProfileRouteArgs> {
  ManagerProfileRoute({
    required String userId,
    required SportMode mode,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         ManagerProfileRoute.name,
         args: ManagerProfileRouteArgs(userId: userId, mode: mode, key: key),
         initialChildren: children,
       );

  static const String name = 'ManagerProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ManagerProfileRouteArgs>();
      return ManagerProfilePage(
        userId: args.userId,
        mode: args.mode,
        key: args.key,
      );
    },
  );
}

class ManagerProfileRouteArgs {
  const ManagerProfileRouteArgs({
    required this.userId,
    required this.mode,
    this.key,
  });

  final String userId;

  final SportMode mode;

  final Key? key;

  @override
  String toString() {
    return 'ManagerProfileRouteArgs{userId: $userId, mode: $mode, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ManagerProfileRouteArgs) return false;
    return userId == other.userId && mode == other.mode && key == other.key;
  }

  @override
  int get hashCode => userId.hashCode ^ mode.hashCode ^ key.hashCode;
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
/// [ProfilePage]
class ProfileRoute extends PageRouteInfo<void> {
  const ProfileRoute({List<PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ProfilePage();
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

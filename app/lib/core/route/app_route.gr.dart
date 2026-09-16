// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_route.dart';

/// generated route for
/// [CreateDuelPage]
class CreateDuelRoute extends PageRouteInfo<CreateDuelRouteArgs> {
  CreateDuelRoute({
    required SportMode mode,
    String? initialOpponent,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         CreateDuelRoute.name,
         args: CreateDuelRouteArgs(
           mode: mode,
           initialOpponent: initialOpponent,
           key: key,
         ),
         initialChildren: children,
       );

  static const String name = 'CreateDuelRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CreateDuelRouteArgs>();
      return CreateDuelPage(
        mode: args.mode,
        initialOpponent: args.initialOpponent,
        key: args.key,
      );
    },
  );
}

class CreateDuelRouteArgs {
  const CreateDuelRouteArgs({
    required this.mode,
    this.initialOpponent,
    this.key,
  });

  final SportMode mode;

  final String? initialOpponent;

  final Key? key;

  @override
  String toString() {
    return 'CreateDuelRouteArgs{mode: $mode, initialOpponent: $initialOpponent, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CreateDuelRouteArgs) return false;
    return mode == other.mode &&
        initialOpponent == other.initialOpponent &&
        key == other.key;
  }

  @override
  int get hashCode => mode.hashCode ^ initialOpponent.hashCode ^ key.hashCode;
}

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
/// [DuelDetailPage]
class DuelDetailRoute extends PageRouteInfo<DuelDetailRouteArgs> {
  DuelDetailRoute({
    required String duelId,
    required SportMode mode,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
         DuelDetailRoute.name,
         args: DuelDetailRouteArgs(duelId: duelId, mode: mode, key: key),
         initialChildren: children,
       );

  static const String name = 'DuelDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DuelDetailRouteArgs>();
      return DuelDetailPage(
        duelId: args.duelId,
        mode: args.mode,
        key: args.key,
      );
    },
  );
}

class DuelDetailRouteArgs {
  const DuelDetailRouteArgs({
    required this.duelId,
    required this.mode,
    this.key,
  });

  final String duelId;

  final SportMode mode;

  final Key? key;

  @override
  String toString() {
    return 'DuelDetailRouteArgs{duelId: $duelId, mode: $mode, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DuelDetailRouteArgs) return false;
    return duelId == other.duelId && mode == other.mode && key == other.key;
  }

  @override
  int get hashCode => duelId.hashCode ^ mode.hashCode ^ key.hashCode;
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

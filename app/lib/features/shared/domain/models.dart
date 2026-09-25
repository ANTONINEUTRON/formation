import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';

/// The three sports. One nav bar tab per mode.
enum SportMode {
  football('football', 'Football', Icons.sports_soccer),
  basketball('basketball', 'Basketball', Icons.sports_basketball),
  americanFootball('american_football', 'American Football', Icons.sports_football);

  const SportMode(this.apiValue, this.label, this.icon);

  /// Wire value shared with the backend.
  final String apiValue;
  final String label;
  final IconData icon;

  static SportMode fromApi(String value) =>
      values.firstWhere((m) => m.apiValue == value);
}

/// Risk category a position slot accepts.
enum RiskTier {
  blueChip('blue_chip', 'Blue chip', AppColors.info),
  stable('stable', 'Stable', AppColors.primary),
  balanced('balanced', 'Balanced', AppColors.secondaryLight),
  growth('growth', 'Growth', AppColors.warning),
  momentum('momentum', 'Momentum', AppColors.accent);

  const RiskTier(this.apiValue, this.label, this.color);

  final String apiValue;
  final String label;
  final Color color;

  static RiskTier fromApi(String value) =>
      values.firstWhere((t) => t.apiValue == value);
}

/// One tokenized equity (xStock) tradeable on Solana.
class XStock extends Equatable {
  const XStock({
    required this.symbol,
    required this.companyName,
    required this.mint,
    required this.tier,
    required this.priceUsd,
    this.change24hPct = 0,
    this.logoUrl,
  });

  factory XStock.fromJson(Map<String, dynamic> json) => XStock(
        symbol: json['symbol'] as String,
        companyName: json['companyName'] as String,
        mint: json['mint'] as String,
        tier: RiskTier.fromApi(json['tier'] as String),
        priceUsd: _double(json['priceUsd']),
        change24hPct: _double(json['change24hPct']),
        logoUrl: json['logoUrl'] as String?,
      );

  final String symbol;
  final String companyName;
  final String mint;
  final RiskTier tier;
  final double priceUsd;
  final double change24hPct;
  final String? logoUrl;

  @override
  List<Object?> get props => [mint, priceUsd, change24hPct];
}

/// A position in a roster shape, e.g. 'PG' or 'GK'.
class PositionSlot extends Equatable {
  const PositionSlot({
    required this.label,
    required this.requiredTier,
    required this.boardPosition,
  });

  final String label;

  /// Null means FLEX: any tier is eligible.
  final RiskTier? requiredTier;

  /// Normalized 0..1 coordinates on the board. Client-only.
  final Offset boardPosition;

  bool accepts(XStock stock) =>
      requiredTier == null || requiredTier == stock.tier;

  @override
  List<Object?> get props => [label, requiredTier, boardPosition];
}

/// A roster position, filled with a stock or empty.
class RosterSlot extends Equatable {
  const RosterSlot({required this.position, this.stock, this.balance = 0});

  final PositionSlot position;
  final XStock? stock;

  /// Token amount held in the wallet.
  final double balance;

  bool get isFilled => stock != null;
  double get valueUsd => (stock?.priceUsd ?? 0) * balance;

  RosterSlot fill(XStock stock, double balance) =>
      RosterSlot(position: position, stock: stock, balance: balance);

  @override
  List<Object?> get props => [position, stock, balance];
}

/// A points event on one pick, e.g. "Goal +4" (docs/formation-scoring.md §5).
class ScoreEvent extends Equatable {
  const ScoreEvent({required this.code, required this.label, required this.points});

  factory ScoreEvent.fromJson(Map<String, dynamic> json) => ScoreEvent(
        code: json['code'] as String,
        label: json['label'] as String,
        points: _double(json['points']),
      );

  final String code;
  final String label;
  final double points;

  @override
  List<Object?> get props => [code, label, points];
}

/// How one pick scored over a gameweek or duel.
class SlotScore extends Equatable {
  const SlotScore({
    required this.slotIndex,
    required this.role,
    required this.mint,
    required this.symbol,
    required this.counted,
    required this.ownReturn,
    required this.alpha,
    required this.base,
    required this.events,
    required this.multiplier,
    required this.total,
  });

  factory SlotScore.fromJson(Map<String, dynamic> json) => SlotScore(
        slotIndex: json['slotIndex'] as int,
        role: json['role'] as String,
        mint: json['mint'] as String,
        symbol: json['symbol'] as String,
        counted: json['counted'] as bool,
        ownReturn: _double(json['ownReturn']),
        alpha: _double(json['alpha']),
        base: _double(json['base']),
        events: [
          for (final e in json['events'] as List)
            ScoreEvent.fromJson(e as Map<String, dynamic>),
        ],
        multiplier: _double(json['multiplier']),
        total: _double(json['total']),
      );

  final int slotIndex;
  final String role;
  final String mint;
  final String symbol;

  /// False when the pick wasn't held all window: it scores nothing.
  final bool counted;
  final double ownReturn;
  final double alpha;
  final double base;
  final List<ScoreEvent> events;
  final double multiplier;
  final double total;

  @override
  List<Object?> get props => [slotIndex, mint, total, counted];
}

/// The current session of the always-running general league. Points bank on
/// every tick, so there is no window to wait for.
class Session extends Equatable {
  const Session({
    required this.startsAt,
    required this.endsAt,
    required this.entered,
    required this.points,
    required this.slots,
    required this.teamEvents,
    required this.substitutionsUsed,
    required this.freeSubstitutionsLeft,
  });

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        entered: json['entered'] as bool,
        points: _double(json['points']),
        slots: [
          for (final s in json['slots'] as List)
            SlotScore.fromJson(s as Map<String, dynamic>),
        ],
        teamEvents: [
          for (final e in json['teamEvents'] as List)
            ScoreEvent.fromJson(e as Map<String, dynamic>),
        ],
        substitutionsUsed: json['substitutionsUsed'] as int? ?? 0,
        freeSubstitutionsLeft: json['freeSubstitutionsLeft'] as int? ?? 0,
      );

  final DateTime startsAt;
  final DateTime endsAt;

  /// True once the team is complete and being scored.
  final bool entered;

  /// Points banked since this session opened.
  final double points;
  final List<SlotScore> slots;
  final List<ScoreEvent> teamEvents;
  final int substitutionsUsed;
  final int freeSubstitutionsLeft;

  Duration get remaining => endsAt.difference(DateTime.now());

  SlotScore? scoreFor(int slotIndex) =>
      slots.where((s) => s.slotIndex == slotIndex).firstOrNull;

  @override
  List<Object?> get props =>
      [startsAt, points, slots, entered, substitutionsUsed];
}

/// A held xStock that isn't in the starting lineup, and can be subbed in.
class BenchSlot extends Equatable {
  const BenchSlot({
    required this.stock,
    required this.balance,
    required this.eligibleSlots,
  });

  factory BenchSlot.fromJson(Map<String, dynamic> json) => BenchSlot(
        stock: XStock.fromJson(json['stock'] as Map<String, dynamic>),
        balance: _double(json['balance']),
        eligibleSlots: [
          for (final i in json['eligibleSlots'] as List) i as int,
        ],
      );

  final XStock stock;
  final double balance;

  /// Slot indexes this stock's tier allows it to play in.
  final List<int> eligibleSlots;

  double get valueUsd => balance * stock.priceUsd;

  @override
  List<Object?> get props => [stock, balance, eligibleSlots];
}

/// A user's team for one sport mode.
class Roster extends Equatable {
  const Roster({
    required this.mode,
    required this.slots,
    this.formation,
    this.captainSlot,
    this.viceCaptainSlot,
    this.classicPoints = 0,
    this.classicRank,
    this.session,
    this.bench = const [],
  });

  factory Roster.fromJson(
    Map<String, dynamic> json,
    List<PositionSlot> shape,
  ) =>
      Roster(
        mode: SportMode.fromApi(json['mode'] as String),
        formation: json['formation'] as String?,
        captainSlot: json['captainSlot'] as int?,
        viceCaptainSlot: json['viceCaptainSlot'] as int?,
        slots: [
          for (final s in (json['slots'] as List).cast<Map<String, dynamic>>())
            RosterSlot(
              position: shape[s['slotIndex'] as int],
              stock: s['stock'] == null
                  ? null
                  : XStock.fromJson(s['stock'] as Map<String, dynamic>),
              balance: _double(s['balance']),
            ),
        ],
        classicPoints: _double(json['classicPoints']),
        classicRank: json['classicRank'] as int?,
        session: json['session'] == null
            ? null
            : Session.fromJson(json['session'] as Map<String, dynamic>),
        bench: [
          for (final b in (json['bench'] as List? ?? const []))
            BenchSlot.fromJson(b as Map<String, dynamic>),
        ],
      );

  final SportMode mode;
  final List<RosterSlot> slots;

  /// Football only, e.g. '4-4-2'.
  final String? formation;
  final int? captainSlot;
  final int? viceCaptainSlot;

  /// Running general-league total, banked on every tick.
  final double classicPoints;
  final int? classicRank;
  final Session? session;

  /// Squad members not in the starting lineup.
  final List<BenchSlot> bench;

  bool get isComplete => slots.every((s) => s.isFilled);
  bool get isEmpty => slots.every((s) => !s.isFilled);
  double get totalValueUsd => slots.fold(0, (sum, s) => sum + s.valueUsd);

  /// 'C', 'V' or null, for badges.
  String? armband(int slotIndex) => captainSlot == slotIndex
      ? 'C'
      : viceCaptainSlot == slotIndex
          ? 'V'
          : null;

  Map<int, String> get picksBySlot => {
        for (var i = 0; i < slots.length; i++)
          if (slots[i].stock != null) i: slots[i].stock!.mint,
      };

  Roster copyWith({
    List<RosterSlot>? slots,
    String? formation,
    int? captainSlot,
    int? viceCaptainSlot,
    double? classicPoints,
    int? classicRank,
    Session? session,
    List<BenchSlot>? bench,
  }) =>
      Roster(
        mode: mode,
        slots: slots ?? this.slots,
        formation: formation ?? this.formation,
        captainSlot: captainSlot ?? this.captainSlot,
        viceCaptainSlot: viceCaptainSlot ?? this.viceCaptainSlot,
        classicPoints: classicPoints ?? this.classicPoints,
        classicRank: classicRank ?? this.classicRank,
        session: session ?? this.session,
        bench: bench ?? this.bench,
      );

  @override
  List<Object?> get props => [
        mode,
        slots,
        formation,
        captainSlot,
        viceCaptainSlot,
        classicPoints,
        classicRank,
        session,
        bench,
      ];
}

/// A player's standing in a Classic league.
class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.walletAddress,
    required this.points,
    this.todayPoints = 0,
    this.streak = 0,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: json['rank'] as int? ?? 0,
        userId: json['userId'] as String,
        username: json['username'] as String,
        walletAddress: json['walletAddress'] as String,
        points: _double(json['points']),
        todayPoints: _double(json['todayPoints']),
        streak: json['streak'] as int? ?? 0,
        isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      );

  final int rank;
  final String userId;
  final String username;
  final String walletAddress;
  final double points;
  final double todayPoints;
  final int streak;
  final bool isCurrentUser;

  @override
  List<Object?> get props =>
      [rank, userId, username, walletAddress, points, todayPoints, streak, isCurrentUser];
}

/// Which slice of league history a leaderboard covers.
enum LeaguePeriodKind {
  allTime('all_time', 'All time'),
  monthly('monthly', 'Month'),
  weekly('weekly', 'Week'),
  custom('custom', 'Custom');

  const LeaguePeriodKind(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// A leaderboard range. The backend derives the bounds for the named periods;
/// only [custom] carries explicit dates.
class LeaguePeriod extends Equatable {
  const LeaguePeriod(this.kind, {this.from, this.to});

  const LeaguePeriod.allTime() : this(LeaguePeriodKind.allTime);

  /// A closed range. [to] may be null to run through to now.
  const LeaguePeriod.custom({required DateTime from, DateTime? to})
      : this(LeaguePeriodKind.custom, from: from, to: to);

  final LeaguePeriodKind kind;
  final DateTime? from;
  final DateTime? to;

  /// Query parameters for `GET /league/:mode`.
  Map<String, String> get query => {
        'period': kind.apiValue,
        if (from != null) 'from': from!.toUtc().toIso8601String(),
        if (to != null) 'to': to!.toUtc().toIso8601String(),
      };

  String get label {
    if (kind != LeaguePeriodKind.custom || from == null) return kind.label;
    final end = to ?? DateTime.now();
    return '${formatShortDate(from!)} – ${formatShortDate(end)}';
  }

  @override
  List<Object?> get props => [kind, from, to];
}

/// The signed-in player's own profile.
///
/// The only shape carrying [email], which is private: it is never part of
/// [Manager], so another player's profile cannot show it.
class Profile extends Equatable {
  const Profile({
    required this.userId,
    required this.username,
    required this.walletAddress,
    required this.followers,
    required this.following,
    this.bio,
    this.email,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        userId: json['userId'] as String,
        username: json['username'] as String,
        bio: json['bio'] as String?,
        email: json['email'] as String?,
        walletAddress: json['walletAddress'] as String,
        followers: json['followers'] as int? ?? 0,
        following: json['following'] as int? ?? 0,
      );

  final String userId;
  final String username;
  final String? bio;

  /// Private to this player; shown only on their own profile screen.
  final String? email;
  final String walletAddress;
  final int followers;
  final int following;

  @override
  List<Object?> get props => [userId, username, bio, email, followers, following];
}

/// Another player's public profile for one sport.
class Manager extends Equatable {
  const Manager({
    required this.userId,
    required this.username,
    required this.bio,
    required this.walletAddress,
    required this.mode,
    required this.points,
    required this.todayPoints,
    required this.streak,
    required this.leaguesWon,
    required this.leaguesPlayed,
    required this.lineup,
    required this.holdings,
    required this.followers,
    required this.following,
    required this.isCurrentUser,
    this.rank,
  });

  factory Manager.fromJson(Map<String, dynamic> json, List<PositionSlot> shape) => Manager(
        userId: json['userId'] as String,
        username: json['username'] as String,
        bio: json['bio'] as String?,
        walletAddress: json['walletAddress'] as String,
        mode: SportMode.fromApi(json['mode'] as String),
        rank: json['rank'] as int?,
        points: _double(json['points']),
        todayPoints: _double(json['todayPoints']),
        streak: json['streak'] as int? ?? 0,
        leaguesWon: json['leaguesWon'] as int? ?? 0,
        leaguesPlayed: json['leaguesPlayed'] as int? ?? 0,
        lineup: [
          for (final s in (json['lineup'] as List? ?? const []).cast<Map<String, dynamic>>())
            RosterSlot(
              position: shape[s['slotIndex'] as int],
              stock: s['stock'] == null
                  ? null
                  : XStock.fromJson(s['stock'] as Map<String, dynamic>),
            ),
        ],
        holdings: [
          for (final h in (json['holdings'] as List? ?? const []))
            ManagerHolding.fromJson(h as Map<String, dynamic>),
        ],
        followers: json['followers'] as int? ?? 0,
        following: json['following'] as bool? ?? false,
        isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      );

  final String userId;
  final String username;
  final String? bio;
  final String walletAddress;
  final SportMode mode;
  final int? rank;
  final double points;
  final double todayPoints;
  final int streak;
  final int leaguesWon;
  final int leaguesPlayed;
  final List<RosterSlot> lineup;

  /// Everything eligible in their wallet — the adopt sheet's contents.
  final List<ManagerHolding> holdings;
  final int followers;
  final bool following;
  final bool isCurrentUser;

  Manager copyWith({bool? following, int? followers}) => Manager(
        userId: userId,
        username: username,
        bio: bio,
        walletAddress: walletAddress,
        mode: mode,
        rank: rank,
        points: points,
        todayPoints: todayPoints,
        streak: streak,
        leaguesWon: leaguesWon,
        leaguesPlayed: leaguesPlayed,
        lineup: lineup,
        holdings: holdings,
        followers: followers ?? this.followers,
        following: following ?? this.following,
        isCurrentUser: isCurrentUser,
      );

  @override
  List<Object?> get props => [userId, mode, points, following, followers];
}

/// One xStock in a manager's wallet.
class ManagerHolding extends Equatable {
  const ManagerHolding({
    required this.stock,
    required this.balance,
    required this.valueUsd,
    required this.starting,
  });

  factory ManagerHolding.fromJson(Map<String, dynamic> json) => ManagerHolding(
        stock: XStock.fromJson(json['stock'] as Map<String, dynamic>),
        balance: _double(json['balance']),
        valueUsd: _double(json['valueUsd']),
        starting: json['starting'] as bool? ?? false,
      );

  final XStock stock;
  final double balance;
  final double valueUsd;

  /// True when it's in their starting lineup, not just their wallet.
  final bool starting;

  @override
  List<Object?> get props => [stock, balance, starting];
}

/// A custom league. A PvP duel is the same object with two members.
class League extends Equatable {
  const League({
    required this.id,
    required this.name,
    required this.mode,
    required this.visibility,
    required this.joinCode,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.memberCount,
    required this.createdBy,
    required this.joined,
    required this.joinable,
    this.maxMembers,
    this.standings = const [],
  });

  factory League.fromJson(Map<String, dynamic> json) => League(
        id: json['id'] as String,
        name: json['name'] as String,
        mode: SportMode.fromApi(json['mode'] as String),
        visibility: json['visibility'] as String,
        joinCode: json['joinCode'] as String,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        status: _leagueStatus(json['status'] as String),
        maxMembers: json['maxMembers'] as int?,
        memberCount: json['memberCount'] as int,
        createdBy: json['createdBy'] as String,
        joined: json['joined'] as bool,
        joinable: json['joinable'] as bool,
        standings: [
          for (final s in (json['standings'] as List? ?? const []))
            LeagueStanding.fromJson(s as Map<String, dynamic>),
        ],
      );

  final String id;
  final String name;
  final SportMode mode;
  final String visibility;
  final String joinCode;
  final DateTime startsAt;
  final DateTime endsAt;
  final LeagueStatus status;
  final int? maxMembers;
  final int memberCount;
  final String createdBy;
  final bool joined;
  final bool joinable;
  final List<LeagueStanding> standings;

  bool get isPrivate => visibility == 'private';

  /// Two-member private leagues are how a PvP challenge is modelled.
  bool get isDuel => maxMembers == 2;

  Duration get startsIn => startsAt.difference(DateTime.now());
  Duration get endsIn => endsAt.difference(DateTime.now());

  @override
  List<Object?> get props => [id, status, memberCount, joined, standings];
}

/// The wire value is 'final', which Dart reserves, so the case is named [fin].
enum LeagueStatus { scheduled, live, fin }

LeagueStatus _leagueStatus(String value) => switch (value) {
      'live' => LeagueStatus.live,
      'final' => LeagueStatus.fin,
      _ => LeagueStatus.scheduled,
    };

extension LeagueStatusApi on LeagueStatus {
  String get label => switch (this) {
        LeagueStatus.scheduled => 'Starts soon',
        LeagueStatus.live => 'Live',
        LeagueStatus.fin => 'Finished',
      };
}

class LeagueStanding extends Equatable {
  const LeagueStanding({
    required this.rank,
    required this.userId,
    required this.username,
    required this.walletAddress,
    required this.points,
    required this.isCurrentUser,
  });

  factory LeagueStanding.fromJson(Map<String, dynamic> json) => LeagueStanding(
        rank: json['rank'] as int,
        userId: json['userId'] as String,
        username: json['username'] as String,
        walletAddress: json['walletAddress'] as String,
        points: _double(json['points']),
        isCurrentUser: json['isCurrentUser'] as bool,
      );

  final int rank;
  final String userId;
  final String username;
  final String walletAddress;
  final double points;
  final bool isCurrentUser;

  @override
  List<Object?> get props => [rank, userId, points, isCurrentUser];
}

/// A Jupiter quote for buying an xStock with USDC.
class SwapQuote extends Equatable {
  const SwapQuote({
    required this.stock,
    required this.inputUsdc,
    required this.estimatedShares,
    required this.priceImpactPct,
    required this.platformFeeBps,
    required this.platformFeeUsdc,
    this.quoteId,
  });

  factory SwapQuote.fromJson(XStock stock, Map<String, dynamic> json) =>
      SwapQuote(
        quoteId: json['quoteId'] as String?,
        stock: stock,
        inputUsdc: _double(json['inputUsdc']),
        estimatedShares: _double(json['estimatedShares']),
        priceImpactPct: _double(json['priceImpactPct']),
        platformFeeBps: json['platformFeeBps'] as int,
        platformFeeUsdc: _double(json['platformFeeUsdc']),
      );

  /// Backend handle for building the swap transaction. Null in fixture mode.
  final String? quoteId;
  final XStock stock;
  final double inputUsdc;
  final double estimatedShares;
  final double priceImpactPct;
  final int platformFeeBps;
  final double platformFeeUsdc;

  @override
  List<Object?> get props => [stock, inputUsdc, estimatedShares];
}

/// What a formation change did: the new team, and who dropped out.
class FormationChange {
  const FormationChange({required this.roster, required this.dropped});

  final Roster roster;
  final List<XStock> dropped;
}

double _double(Object? value) => (value as num?)?.toDouble() ?? 0;

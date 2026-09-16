import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/shared/domain/lineup.dart';

/// The three roster shapes. One nav bar tab per mode.
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
        priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? 0,
        change24hPct: (json['change24hPct'] as num?)?.toDouble() ?? 0,
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

/// A user's live roster for one sport mode.
class Roster extends Equatable {
  const Roster({
    required this.mode,
    required this.slots,
    this.lastReturnPct = 0,
    this.classicPoints = 0,
    this.classicRank,
    this.lastTickAt,
    this.lineup,
  });

  final SportMode mode;
  final List<RosterSlot> slots;

  /// Football only: starting XI, bench order and armbands.
  final Lineup? lineup;

  /// Roster return over the most recent scoring window, as a fraction.
  final double lastReturnPct;
  final int classicPoints;
  final int? classicRank;
  final DateTime? lastTickAt;

  bool get isComplete => slots.every((s) => s.isFilled);
  bool get isEmpty => slots.every((s) => !s.isFilled);
  double get totalValueUsd => slots.fold(0, (sum, s) => sum + s.valueUsd);

  Roster copyWith({
    List<RosterSlot>? slots,
    double? lastReturnPct,
    int? classicPoints,
    int? classicRank,
    DateTime? lastTickAt,
    Lineup? lineup,
  }) =>
      Roster(
        mode: mode,
        slots: slots ?? this.slots,
        lastReturnPct: lastReturnPct ?? this.lastReturnPct,
        classicPoints: classicPoints ?? this.classicPoints,
        classicRank: classicRank ?? this.classicRank,
        lastTickAt: lastTickAt ?? this.lastTickAt,
        lineup: lineup ?? this.lineup,
      );

  @override
  List<Object?> get props =>
      [mode, slots, lastReturnPct, classicPoints, classicRank, lastTickAt, lineup];
}

/// A player's standing in a Classic league.
class LeaderboardEntry extends Equatable {
  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.walletAddress,
    required this.points,
    this.streak = 0,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: json['rank'] as int? ?? 0,
        userId: json['userId'] as String,
        username: json['username'] as String,
        walletAddress: json['walletAddress'] as String,
        points: json['points'] as int? ?? 0,
        streak: json['streak'] as int? ?? 0,
        isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      );

  final int rank;
  final String userId;
  final String username;
  final String walletAddress;
  final int points;
  final int streak;
  final bool isCurrentUser;

  @override
  List<Object?> get props =>
      [rank, userId, username, walletAddress, points, streak, isCurrentUser];
}

enum DuelStatus { pending, active, settled, declined }

/// Preset duel durations. 1h exists so a duel can resolve during a demo.
const duelDurations = [
  Duration(hours: 1),
  Duration(hours: 6),
  Duration(hours: 24),
  Duration(days: 3),
  Duration(days: 7),
];

String formatDuelDuration(Duration d) =>
    d.inHours < 24 ? '${d.inHours}h' : '${d.inDays}d';

/// A head-to-head challenge between two players in one sport mode.
class Duel extends Equatable {
  const Duel({
    required this.id,
    required this.challenger,
    required this.opponent,
    required this.mode,
    required this.duration,
    required this.status,
    this.startTime,
    this.endTime,
    this.challengerReturnPct,
    this.opponentReturnPct,
    this.winnerId,
  });

  factory Duel.fromJson(Map<String, dynamic> json) => Duel(
        id: json['id'] as String,
        challenger: LeaderboardEntry.fromJson(
            json['challenger'] as Map<String, dynamic>),
        opponent:
            LeaderboardEntry.fromJson(json['opponent'] as Map<String, dynamic>),
        mode: SportMode.fromApi(json['mode'] as String),
        duration: Duration(hours: json['durationHours'] as int),
        status: DuelStatus.values.byName(json['status'] as String),
        startTime: _date(json['startTime']),
        endTime: _date(json['endTime']),
        challengerReturnPct: (json['challengerReturnPct'] as num?)?.toDouble(),
        opponentReturnPct: (json['opponentReturnPct'] as num?)?.toDouble(),
        winnerId: json['winnerId'] as String?,
      );

  final String id;
  final LeaderboardEntry challenger;
  final LeaderboardEntry opponent;
  final SportMode mode;
  final Duration duration;
  final DuelStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  final double? challengerReturnPct;
  final double? opponentReturnPct;
  final String? winnerId;

  bool get involvesCurrentUser =>
      challenger.isCurrentUser || opponent.isCurrentUser;

  /// The current user's side of the duel.
  LeaderboardEntry get me => challenger.isCurrentUser ? challenger : opponent;
  LeaderboardEntry get rival => challenger.isCurrentUser ? opponent : challenger;
  double? get myReturnPct =>
      challenger.isCurrentUser ? challengerReturnPct : opponentReturnPct;
  double? get rivalReturnPct =>
      challenger.isCurrentUser ? opponentReturnPct : challengerReturnPct;

  /// True when the current user received this invite and must respond.
  bool get awaitingMyResponse =>
      status == DuelStatus.pending && opponent.isCurrentUser;

  bool get iWon => winnerId != null && winnerId == me.userId;

  Duel copyWith({
    DuelStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    double? challengerReturnPct,
    double? opponentReturnPct,
    String? winnerId,
  }) =>
      Duel(
        id: id,
        challenger: challenger,
        opponent: opponent,
        mode: mode,
        duration: duration,
        status: status ?? this.status,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        challengerReturnPct: challengerReturnPct ?? this.challengerReturnPct,
        opponentReturnPct: opponentReturnPct ?? this.opponentReturnPct,
        winnerId: winnerId ?? this.winnerId,
      );

  @override
  List<Object?> get props => [
        id,
        status,
        startTime,
        endTime,
        challengerReturnPct,
        opponentReturnPct,
        winnerId,
      ];
}

/// A win record, anchored on-chain by a transaction signature.
class Trophy extends Equatable {
  const Trophy({
    required this.id,
    required this.title,
    required this.mode,
    required this.awardedAt,
    this.txSignature,
  });

  factory Trophy.fromJson(Map<String, dynamic> json) => Trophy(
        id: json['id'] as String,
        title: json['title'] as String,
        mode: SportMode.fromApi(json['mode'] as String),
        awardedAt: DateTime.parse(json['awardedAt'] as String),
        txSignature: json['txSignature'] as String?,
      );

  final String id;
  final String title;
  final SportMode mode;
  final DateTime awardedAt;
  final String? txSignature;

  @override
  List<Object?> get props => [id, txSignature];
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
        inputUsdc: (json['inputUsdc'] as num).toDouble(),
        estimatedShares: (json['estimatedShares'] as num).toDouble(),
        priceImpactPct: (json['priceImpactPct'] as num).toDouble(),
        platformFeeBps: json['platformFeeBps'] as int,
        platformFeeUsdc: (json['platformFeeUsdc'] as num).toDouble(),
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

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

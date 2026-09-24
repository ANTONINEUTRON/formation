import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';

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

/// The scoring window a team is locked into.
class Gameweek extends Equatable {
  const Gameweek({
    required this.id,
    required this.number,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.entered,
    required this.points,
    required this.slots,
    required this.teamEvents,
  });

  factory Gameweek.fromJson(Map<String, dynamic> json) => Gameweek(
        id: json['id'] as String,
        number: json['number'] as int,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: DateTime.parse(json['endsAt'] as String),
        status: json['status'] as String,
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
      );

  final String id;
  final int number;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;

  /// True once this team's lineup is locked into the gameweek.
  final bool entered;
  final double points;
  final List<SlotScore> slots;
  final List<ScoreEvent> teamEvents;

  bool get isLive => status == 'live';
  Duration get remaining => endsAt.difference(DateTime.now());

  SlotScore? scoreFor(int slotIndex) =>
      slots.where((s) => s.slotIndex == slotIndex).firstOrNull;

  @override
  List<Object?> get props => [id, status, points, slots, entered];
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
    this.gameweek,
    this.pendingChanges = false,
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
        gameweek: json['gameweek'] == null
            ? null
            : Gameweek.fromJson(json['gameweek'] as Map<String, dynamic>),
        pendingChanges: json['pendingChanges'] as bool? ?? false,
      );

  final SportMode mode;
  final List<RosterSlot> slots;

  /// Football only, e.g. '4-4-2'.
  final String? formation;
  final int? captainSlot;
  final int? viceCaptainSlot;

  /// Season total from finished gameweeks, plus the live one.
  final double classicPoints;
  final int? classicRank;
  final Gameweek? gameweek;

  /// True when the team has changed since the gameweek locked.
  final bool pendingChanges;

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
    Gameweek? gameweek,
    bool? pendingChanges,
  }) =>
      Roster(
        mode: mode,
        slots: slots ?? this.slots,
        formation: formation ?? this.formation,
        captainSlot: captainSlot ?? this.captainSlot,
        viceCaptainSlot: viceCaptainSlot ?? this.viceCaptainSlot,
        classicPoints: classicPoints ?? this.classicPoints,
        classicRank: classicRank ?? this.classicRank,
        gameweek: gameweek ?? this.gameweek,
        pendingChanges: pendingChanges ?? this.pendingChanges,
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
        gameweek,
        pendingChanges,
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
    this.gameweekPoints = 0,
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
        gameweekPoints: _double(json['gameweekPoints']),
        streak: json['streak'] as int? ?? 0,
        isCurrentUser: json['isCurrentUser'] as bool? ?? false,
      );

  final int rank;
  final String userId;
  final String username;
  final String walletAddress;
  final double points;
  final double gameweekPoints;
  final int streak;
  final bool isCurrentUser;

  @override
  List<Object?> get props =>
      [rank, userId, username, walletAddress, points, gameweekPoints, streak, isCurrentUser];
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

/// One head-to-head category in a basketball duel; higher always wins.
class DuelCategory extends Equatable {
  const DuelCategory({
    required this.code,
    required this.name,
    required this.challenger,
    required this.opponent,
    required this.winner,
  });

  factory DuelCategory.fromJson(Map<String, dynamic> json) => DuelCategory(
        code: json['code'] as String,
        name: json['name'] as String,
        challenger: _double(json['challenger']),
        opponent: _double(json['opponent']),
        winner: json['winner'] as String,
      );

  final String code;
  final String name;
  final double challenger;
  final double opponent;

  /// 'challenger', 'opponent' or 'tie'.
  final String winner;

  /// Percentages read better than raw fractions for these two.
  bool get isPercent => code == 'alpha' || code == 'hitRate' || code == 'bestPick' || code == 'defense';

  @override
  List<Object?> get props => [code, challenger, opponent, winner];
}

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
    this.challengerPoints,
    this.opponentPoints,
    this.categories,
    this.challengerSlots = const [],
    this.opponentSlots = const [],
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
        challengerPoints: _nullableDouble(json['challengerPoints']),
        opponentPoints: _nullableDouble(json['opponentPoints']),
        categories: json['categories'] == null
            ? null
            : [
                for (final c in json['categories'] as List)
                  DuelCategory.fromJson(c as Map<String, dynamic>),
              ],
        challengerSlots: _slots(json['challengerBreakdown']),
        opponentSlots: _slots(json['opponentBreakdown']),
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
  final double? challengerPoints;
  final double? opponentPoints;

  /// Basketball duels are decided on categories.
  final List<DuelCategory>? categories;
  final List<SlotScore> challengerSlots;
  final List<SlotScore> opponentSlots;
  final String? winnerId;

  bool get involvesCurrentUser =>
      challenger.isCurrentUser || opponent.isCurrentUser;

  /// The current user's side of the duel.
  LeaderboardEntry get me => challenger.isCurrentUser ? challenger : opponent;
  LeaderboardEntry get rival => challenger.isCurrentUser ? opponent : challenger;
  double get myPoints =>
      (challenger.isCurrentUser ? challengerPoints : opponentPoints) ?? 0;
  double get rivalPoints =>
      (challenger.isCurrentUser ? opponentPoints : challengerPoints) ?? 0;
  List<SlotScore> get mySlots =>
      challenger.isCurrentUser ? challengerSlots : opponentSlots;

  /// True when the current user received this invite and must respond.
  bool get awaitingMyResponse =>
      status == DuelStatus.pending && opponent.isCurrentUser;

  bool get iWon => winnerId != null && winnerId == me.userId;

  Duel copyWith({DuelStatus? status}) => Duel(
        id: id,
        challenger: challenger,
        opponent: opponent,
        mode: mode,
        duration: duration,
        status: status ?? this.status,
        startTime: startTime,
        endTime: endTime,
        challengerPoints: challengerPoints,
        opponentPoints: opponentPoints,
        categories: categories,
        challengerSlots: challengerSlots,
        opponentSlots: opponentSlots,
        winnerId: winnerId,
      );

  @override
  List<Object?> get props => [
        id,
        status,
        startTime,
        endTime,
        challengerPoints,
        opponentPoints,
        categories,
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

double? _nullableDouble(Object? value) => (value as num?)?.toDouble();

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

List<SlotScore> _slots(Object? breakdown) {
  if (breakdown == null) return const [];
  final slots = (breakdown as Map<String, dynamic>)['slots'] as List?;
  return [
    for (final s in slots ?? const [])
      SlotScore.fromJson(s as Map<String, dynamic>),
  ];
}

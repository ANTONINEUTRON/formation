import 'package:equatable/equatable.dart';

import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/domain/models.dart';

/// How each sport talks about the time before its season: football plays
/// pre-season friendlies before the big kick-off; basketball and American
/// football play preseason games before tip-off and kickoff.
extension SeasonTerms on SportMode {
  /// "Pre-season" / "Preseason".
  String get preSeason => this == SportMode.football ? 'Pre-season' : 'Preseason';

  /// "Pre-season friendlies" / "Preseason games".
  String get preSeasonGames => this == SportMode.football ? 'Pre-season friendlies' : 'Preseason games';

  /// What starts a season or a match: "Kick-off", "Tip-off", "Kickoff".
  String get seasonStart => switch (this) {
    SportMode.football => 'Kick-off',
    SportMode.basketball => 'Tip-off',
    SportMode.americanFootball => 'Kickoff',
  };
}

/// Seasons, match weeks and fixtures (SCORING_PLAN.md Phase 2).
///
/// A match week kicks off Monday 9:30am ET and reaches full time Friday 4pm
/// ET; the weekend in between is the transfer window, when substitutions are
/// free. Twelve match weeks make a season.

double _num(Object? value) => switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

class MatchWeek extends Equatable {
  const MatchWeek({
    required this.number,
    required this.season,
    required this.weekOfSeason,
    required this.kickOff,
    required this.fullTime,
    required this.nextKickOff,
    this.points = 0,
    this.preSeason = false,
  });

  factory MatchWeek.fromJson(Map<String, dynamic> json) => MatchWeek(
        number: json['number'] as int,
        season: json['season'] as int,
        weekOfSeason: json['weekOfSeason'] as int,
        kickOff: DateTime.parse(json['kickOff'] as String),
        fullTime: DateTime.parse(json['fullTime'] as String),
        nextKickOff: DateTime.parse(json['nextKickOff'] as String),
        points: _num(json['points']),
        preSeason: json['preSeason'] as bool? ?? false,
      );

  /// Before season 1 starts: points bank but don't count toward any season.
  final bool preSeason;

  final int number;
  final int season;

  /// 1–12.
  final int weekOfSeason;
  final DateTime kickOff;
  final DateTime fullTime;
  final DateTime nextKickOff;

  /// Points banked between kick-off and full time.
  final double points;

  bool get isPlaying {
    final now = DateTime.now();
    return now.isAfter(kickOff) && now.isBefore(fullTime);
  }

  String get label => 'Season $season · Week $weekOfSeason';

  /// [label] in [mode]'s words, e.g. "Pre-season friendlies · Season 1
  /// kick-off 19 Oct" before the season starts.
  String labelFor(SportMode mode) => preSeason
      ? '${mode.preSeasonGames} · Season $season ${mode.seasonStart.toLowerCase()} ${formatShortDate(kickOff.toLocal())}'
      : label;

  @override
  List<Object?> get props => [number, points];
}

class Fixture extends Equatable {
  const Fixture({
    required this.week,
    required this.weekOfSeason,
    required this.kickOff,
    required this.fullTime,
    required this.homeId,
    required this.homeName,
    required this.awayId,
    required this.awayName,
    required this.homePoints,
    required this.awayPoints,
    required this.isFinal,
  });

  factory Fixture.fromJson(Map<String, dynamic> json) => Fixture(
        week: json['week'] as int,
        weekOfSeason: json['weekOfSeason'] as int,
        kickOff: DateTime.parse(json['kickOff'] as String),
        fullTime: DateTime.parse(json['fullTime'] as String),
        homeId: json['homeId'] as String,
        homeName: json['homeName'] as String,
        awayId: json['awayId'] as String?,
        awayName: json['awayName'] as String?,
        homePoints: json['homePoints'] == null ? null : _num(json['homePoints']),
        awayPoints: json['awayPoints'] == null ? null : _num(json['awayPoints']),
        isFinal: json['status'] == 'final',
      );

  final int week;
  final int weekOfSeason;
  final DateTime kickOff;
  final DateTime fullTime;
  final String homeId;
  final String homeName;

  /// Null is a bye.
  final String? awayId;
  final String? awayName;
  final double? homePoints;
  final double? awayPoints;
  final bool isFinal;

  bool get isBye => awayId == null;
  bool involves(String userId) => homeId == userId || awayId == userId;

  @override
  List<Object?> get props => [week, homeId, awayId, homePoints, awayPoints, isFinal];
}

class LeagueTableRow extends Equatable {
  const LeagueTableRow({
    required this.rank,
    required this.userId,
    required this.username,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.tablePoints,
    required this.form,
  });

  factory LeagueTableRow.fromJson(Map<String, dynamic> json) => LeagueTableRow(
        rank: json['rank'] as int,
        userId: json['userId'] as String,
        username: json['username'] as String,
        played: json['played'] as int,
        won: json['won'] as int,
        drawn: json['drawn'] as int,
        lost: json['lost'] as int,
        pointsFor: _num(json['pointsFor']),
        pointsAgainst: _num(json['pointsAgainst']),
        tablePoints: json['tablePoints'] as int,
        form: [for (final f in json['form'] as List? ?? const []) f as String],
      );

  final int rank;
  final String userId;
  final String username;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final double pointsFor;
  final double pointsAgainst;

  /// 3 a win, 1 a draw.
  final int tablePoints;

  /// Last five results, oldest first: 'W', 'D' or 'L'.
  final List<String> form;

  @override
  List<Object?> get props => [userId, played, tablePoints, form];
}

/// How a player's match week went: the full-time result card.
class MatchWeekResult extends Equatable {
  const MatchWeekResult({
    required this.week,
    required this.isFinal,
    required this.points,
    required this.rank,
    required this.players,
    required this.manOfTheMatch,
    required this.goals,
    required this.turningPoint,
  });

  factory MatchWeekResult.fromJson(Map<String, dynamic> json) {
    final motm = json['manOfTheMatch'] as Map<String, dynamic>?;
    final turning = json['turningPoint'] as Map<String, dynamic>?;
    return MatchWeekResult(
      week: MatchWeek.fromJson(json['week'] as Map<String, dynamic>),
      isFinal: json['final'] as bool,
      points: _num(json['points']),
      rank: json['rank'] as int?,
      players: json['players'] as int? ?? 0,
      manOfTheMatch: motm == null ? null : (symbol: motm['symbol'] as String, points: _num(motm['points'])),
      goals: [
        for (final g in json['goals'] as List? ?? const [])
          (
            at: DateTime.parse((g as Map)['at'] as String),
            symbol: g['symbol'] as String,
            label: g['label'] as String,
            points: _num(g['points']),
            provisional: g['provisional'] == true,
          ),
      ],
      turningPoint:
          turning == null ? null : (at: DateTime.parse(turning['at'] as String), points: _num(turning['points'])),
    );
  }

  final MatchWeek week;
  final bool isFinal;
  final double points;
  final int? rank;
  final int players;
  final ({String symbol, double points})? manOfTheMatch;
  /// Goals in order; today's are [provisional] until the daily rollup.
  final List<({DateTime at, String symbol, String label, double points, bool provisional})> goals;
  final ({DateTime at, double points})? turningPoint;

  @override
  List<Object?> get props => [week, isFinal, points, rank];
}

/// A role event as it happens today (SCORING_PLAN.md §3.1): provisional until
/// the daily rollup confirms it, or disallowed if the price fell back.
class LiveEvent extends Equatable {
  const LiveEvent({
    required this.slotIndex,
    required this.mint,
    required this.symbol,
    required this.code,
    required this.label,
    required this.points,
    required this.status,
    required this.at,
  });

  factory LiveEvent.fromJson(Map<String, dynamic> json) => LiveEvent(
        slotIndex: json['slotIndex'] as int,
        mint: json['mint'] as String,
        symbol: json['symbol'] as String,
        code: json['code'] as String,
        label: json['label'] as String,
        points: _num(json['points']),
        status: json['status'] as String,
        at: DateTime.parse(json['at'] as String),
      );

  final int slotIndex;
  final String mint;
  final String symbol;
  final String code;
  final String label;
  final double points;

  /// 'provisional', 'confirmed' or 'disallowed'.
  final String status;
  final DateTime at;

  bool get isProvisional => status == 'provisional';
  bool get isDisallowed => status == 'disallowed';

  /// A goal, or the sport's equivalent: worth a celebration.
  bool get isGoal =>
      points > 0 && const {'goal', 'bucket', 'touchdown', 'block', 'double_double', 'field_goal'}.contains(code);

  @override
  List<Object?> get props => [slotIndex, mint, code, label, points, status];
}

/// A private-league fixture being played this week.
class LiveFixture extends Equatable {
  const LiveFixture({
    required this.leagueId,
    required this.leagueName,
    required this.opponent,
    required this.points,
    required this.opponentPoints,
    required this.isFinal,
  });

  factory LiveFixture.fromJson(Map<String, dynamic> json) => LiveFixture(
        leagueId: json['leagueId'] as String,
        leagueName: json['leagueName'] as String,
        opponent: json['opponent'] as String?,
        points: _num(json['points']),
        opponentPoints: _num(json['opponentPoints']),
        isFinal: json['final'] as bool? ?? false,
      );

  final String leagueId;
  final String leagueName;

  /// Null is a bye.
  final String? opponent;
  final double points;
  final double opponentPoints;
  final bool isFinal;

  @override
  List<Object?> get props => [leagueId, opponent, points, opponentPoints, isFinal];
}

/// Skill, made visible (SCORING_PLAN.md §3.2).
class Skill extends Equatable {
  const Skill({
    required this.rating,
    required this.weeks,
    required this.ranked,
    required this.alphaPerWeekPct,
    required this.hitRatePct,
    required this.shrewdCaptainPct,
    required this.form,
  });

  factory Skill.fromJson(Map<String, dynamic> json) => Skill(
        rating: _num(json['rating']),
        weeks: json['weeks'] as int,
        ranked: json['ranked'] as bool? ?? false,
        alphaPerWeekPct: _num(json['alphaPerWeekPct']),
        hitRatePct: json['hitRatePct'] as int? ?? 0,
        shrewdCaptainPct: json['shrewdCaptainPct'] as int?,
        form: [for (final f in json['form'] as List? ?? const []) f as String],
      );

  /// 0–100; 50 matches the market. Risk-adjusted: steady beats lucky.
  final double rating;
  final int weeks;

  /// Enough weeks to appear on the Skill board.
  final bool ranked;

  /// "Beats the market by +2.1% a week on average."
  final double alphaPerWeekPct;

  /// Share of picks that beat the S&P 500 over their week.
  final int hitRatePct;

  /// Share of weeks the captain outscored the team's average pick.
  final int? shrewdCaptainPct;

  /// Last five weeks against the market, oldest first.
  final List<String> form;

  @override
  List<Object?> get props => [rating, weeks, alphaPerWeekPct, hitRatePct, form];
}

/// The Assistant Manager's weekly portfolio health card (SCORING_PLAN.md
/// Phase 5): balance, explained in football terms.
class PortfolioHealth extends Equatable {
  const PortfolioHealth({
    required this.weekOfSeason,
    required this.season,
    required this.points,
    required this.tiers,
    required this.sectors,
    required this.balanceSectors,
    required this.balanceNeeded,
    required this.balanceBonus,
    required this.balanceEarned,
    required this.carried,
    required this.dragged,
    required this.lessons,
  });

  factory PortfolioHealth.fromJson(Map<String, dynamic> json) {
    final balance = json['balance'] as Map<String, dynamic>? ?? const {};
    ({String symbol, double points})? pick(Object? v) =>
        v is Map ? (symbol: v['symbol'] as String, points: _num(v['points'])) : null;
    return PortfolioHealth(
      weekOfSeason: json['weekOfSeason'] as int? ?? 1,
      season: json['season'] as int? ?? 1,
      points: _num(json['points']),
      tiers: {
        for (final t in json['tiers'] as List? ?? const [])
          (t as Map)['tier'] as String: t['count'] as int,
      },
      sectors: [
        for (final s in json['sectors'] as List? ?? const [])
          (label: (s as Map)['label'] as String, sharePct: s['sharePct'] as int),
      ],
      balanceSectors: balance['sectors'] as int? ?? 0,
      balanceNeeded: balance['needed'] as int? ?? 4,
      balanceBonus: balance['bonus'] as int? ?? 0,
      balanceEarned: balance['earned'] as bool? ?? false,
      carried: pick(json['carried']),
      dragged: pick(json['dragged']),
      lessons: [for (final l in json['lessons'] as List? ?? const []) l as String],
    );
  }

  final int weekOfSeason;
  final int season;
  final double points;

  /// Tier api value -> picks in it.
  final Map<String, int> tiers;

  /// Share of the team's value by sector, biggest first.
  final List<({String label, int sharePct})> sectors;
  final int balanceSectors;
  final int balanceNeeded;
  final int balanceBonus;
  final bool balanceEarned;
  final ({String symbol, double points})? carried;
  final ({String symbol, double points})? dragged;
  final List<String> lessons;

  bool get isBalanced => balanceSectors >= balanceNeeded;

  @override
  List<Object?> get props => [weekOfSeason, points, sectors, lessons, balanceEarned];
}

/// What a Manager wants pushed, and when not to (SCORING_PLAN.md Phase 4).
class PushSettings extends Equatable {
  const PushSettings({
    required this.available,
    required this.devices,
    required this.categories,
    required this.quietEnabled,
    required this.quietStart,
    required this.quietEnd,
    required this.timeZone,
    required this.dailyBudget,
  });

  factory PushSettings.fromJson(Map<String, dynamic> json) => PushSettings(
        available: json['available'] as bool? ?? false,
        devices: json['devices'] as int? ?? 0,
        categories: {
          for (final e in (json['categories'] as Map<String, dynamic>? ?? const {}).entries)
            e.key: e.value as bool,
        },
        quietEnabled: json['quietEnabled'] as bool? ?? true,
        quietStart: json['quietStart'] as int? ?? 22 * 60,
        quietEnd: json['quietEnd'] as int? ?? 8 * 60,
        timeZone: json['timeZone'] as String? ?? 'UTC',
        dailyBudget: json['dailyBudget'] as int? ?? 10,
      );

  /// The order and wording the settings screen shows.
  static const categoryLabels = {
    'match_week': ('Match week', 'Kick-off, half-time and your full-time result'),
    'goals': ('Live goals', 'When a pick scores, at most once a pick a day'),
    'season': ('Season finale', 'Where you finished, and the new season'),
    'points': ('Daily points', "Yesterday's role events"),
    'leagues': ('Leagues', 'Starts, results and new members'),
    'social': ('Managers', 'New followers and moves by Managers you follow'),
  };

  /// False when the server has no FCM credentials.
  final bool available;
  final int devices;
  final Map<String, bool> categories;
  final bool quietEnabled;

  /// Minutes after local midnight.
  final int quietStart;
  final int quietEnd;
  final String timeZone;
  final int dailyBudget;

  bool isOn(String category) => categories[category] ?? true;

  @override
  List<Object?> get props => [available, devices, categories, quietEnabled, quietStart, quietEnd, timeZone];
}

/// A finished season on a manager's profile.
class SeasonResult extends Equatable {
  const SeasonResult({required this.season, required this.points, required this.rank, required this.players});

  factory SeasonResult.fromJson(Map<String, dynamic> json) => SeasonResult(
        season: json['season'] as int,
        points: _num(json['points']),
        rank: json['rank'] as int,
        players: json['players'] as int,
      );

  final int season;
  final double points;
  final int rank;
  final int players;

  @override
  List<Object?> get props => [season, points, rank];
}

/// An honour kept across seasons ("Season 3 champion", "Golden Boot").
/// Not `Badge`, which Flutter's material library already names.
class ManagerBadge extends Equatable {
  const ManagerBadge({required this.code, required this.label, this.season});

  factory ManagerBadge.fromJson(Map<String, dynamic> json) => ManagerBadge(
        code: json['code'] as String,
        label: json['label'] as String,
        season: json['season'] as int?,
      );

  final String code;
  final String label;
  final int? season;

  @override
  List<Object?> get props => [code, label, season];
}

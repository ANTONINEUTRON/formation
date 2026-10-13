import 'package:equatable/equatable.dart';

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
  });

  factory MatchWeek.fromJson(Map<String, dynamic> json) => MatchWeek(
        number: json['number'] as int,
        season: json['season'] as int,
        weekOfSeason: json['weekOfSeason'] as int,
        kickOff: DateTime.parse(json['kickOff'] as String),
        fullTime: DateTime.parse(json['fullTime'] as String),
        nextKickOff: DateTime.parse(json['nextKickOff'] as String),
        points: _num(json['points']),
      );

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
  final List<({DateTime at, String symbol, String label, double points})> goals;
  final ({DateTime at, double points})? turningPoint;

  @override
  List<Object?> get props => [week, isFinal, points, rank];
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

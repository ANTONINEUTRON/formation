import 'package:equatable/equatable.dart';

/// Football squad roles by slot index, mirroring FPL's 15-player squad:
/// 2 goalkeepers, 5 defenders, 5 midfielders, 3 forwards.
/// Must match `FOOTBALL_SQUAD_ROLES` in `backend/src/domain/sport.ts`.
const footballSquadRoles = [
  'GK', 'GK',
  'DEF', 'DEF', 'DEF', 'DEF', 'DEF',
  'MID', 'MID', 'MID', 'MID', 'MID',
  'FWD', 'FWD', 'FWD',
];

/// Outfield shape of a starting XI; the goalkeeper is implied.
class Formation extends Equatable {
  const Formation(this.def, this.mid, this.fwd);

  final int def;
  final int mid;
  final int fwd;

  String get name => '$def-$mid-$fwd';

  /// FPL rules: 3–5 defenders, 2–5 midfielders, 1–3 forwards.
  bool get isValid =>
      def >= 3 && def <= 5 && mid >= 2 && mid <= 5 && fwd >= 1 && fwd <= 3 && def + mid + fwd == 10;

  @override
  List<Object?> get props => [def, mid, fwd];
}

/// Every formation FPL allows.
const footballFormations = [
  Formation(3, 4, 3),
  Formation(3, 5, 2),
  Formation(4, 3, 3),
  Formation(4, 4, 2),
  Formation(4, 5, 1),
  Formation(5, 2, 3),
  Formation(5, 3, 2),
  Formation(5, 4, 1),
];

/// Which squad players start, the bench order, and the armbands.
///
/// All operations return a new lineup and keep FPL rules: 11 starters with
/// one goalkeeper in a valid formation, the backup keeper first on the bench,
/// and captain / vice-captain only on starters.
class Lineup extends Equatable {
  const Lineup({required this.starters, required this.bench, this.captain, this.viceCaptain});

  factory Lineup.fromJson(Map<String, dynamic> json) => Lineup(
        starters: (json['starters'] as List).cast<int>(),
        bench: (json['bench'] as List).cast<int>(),
        captain: json['captain'] as int?,
        viceCaptain: json['viceCaptain'] as int?,
      );

  /// 4-4-2 with the first players of each role starting.
  factory Lineup.defaultFootball() => _build(
        const Formation(4, 4, 2),
        preference: [for (var i = 0; i < footballSquadRoles.length; i++) i],
        previousBench: const [],
      );

  /// Slot indices on the pitch, ascending (so grouped GK, DEF, MID, FWD).
  final List<int> starters;

  /// Substitution order; `bench.first` is always the backup goalkeeper.
  final List<int> bench;
  final int? captain;
  final int? viceCaptain;

  Map<String, dynamic> toJson() => {
        'starters': starters,
        'bench': bench,
        'captain': captain,
        'viceCaptain': viceCaptain,
      };

  bool isStarter(int slot) => starters.contains(slot);

  Formation get formation {
    int count(String role) => starters.where((s) => footballSquadRoles[s] == role).length;
    return Formation(count('DEF'), count('MID'), count('FWD'));
  }

  bool get isValid {
    final all = {...starters, ...bench};
    return starters.length == 11 &&
        bench.length == 4 &&
        all.length == footballSquadRoles.length &&
        all.every((s) => s >= 0 && s < footballSquadRoles.length) &&
        starters.where((s) => footballSquadRoles[s] == 'GK').length == 1 &&
        footballSquadRoles[bench.first] == 'GK' &&
        formation.isValid &&
        (captain == null || isStarter(captain!)) &&
        (viceCaptain == null || (isStarter(viceCaptain!) && viceCaptain != captain));
  }

  /// Scoring weight: 2 for the captain, 1 for starters, 0 for the bench.
  double weightOf(int slot) => captain == slot ? 2 : isStarter(slot) ? 1 : 0;

  int? benchOrderOf(int slot) {
    final i = bench.indexOf(slot);
    return i == -1 ? null : i;
  }

  /// 'C', 'V' or null, for badges.
  String? armband(int slot) => captain == slot ? 'C' : viceCaptain == slot ? 'V' : null;

  /// Rearranges into [target], keeping current starters where possible and
  /// promoting substitutes in bench order.
  Lineup withFormation(Formation target) => _build(
        target,
        preference: [...starters, ...bench],
        previousBench: bench,
        captain: captain,
        viceCaptain: viceCaptain,
      );

  /// Swaps a starter with a substitute, FPL style. Returns null when the swap
  /// isn't allowed (two starters, keeper for outfielder, invalid formation).
  Lineup? substitute(int a, int b) {
    if (isStarter(a) == isStarter(b)) return null;
    final off = isStarter(a) ? a : b;
    final on = isStarter(a) ? b : a;
    if ((footballSquadRoles[off] == 'GK') != (footballSquadRoles[on] == 'GK')) return null;
    final next = Lineup(
      starters: [for (final s in starters) s == off ? on : s]..sort(),
      bench: [for (final s in bench) s == on ? off : s],
    )._withArmbands(captain, viceCaptain);
    return next.formation.isValid ? next : null;
  }

  Lineup withCaptain(int slot) => !isStarter(slot)
      ? this
      : Lineup(
          starters: starters,
          bench: bench,
          captain: slot,
          viceCaptain: viceCaptain == slot ? captain : viceCaptain,
        );

  Lineup withViceCaptain(int slot) => !isStarter(slot)
      ? this
      : Lineup(
          starters: starters,
          bench: bench,
          captain: captain == slot ? viceCaptain : captain,
          viceCaptain: slot,
        );

  /// Drops armbands from benched players; a benched captain hands the
  /// armband to the vice-captain.
  Lineup _withArmbands(int? captain, int? viceCaptain) {
    int? c = captain != null && isStarter(captain) ? captain : null;
    int? v = viceCaptain != null && isStarter(viceCaptain) && viceCaptain != c ? viceCaptain : null;
    if (c == null && v != null) {
      c = v;
      v = null;
    }
    return Lineup(starters: starters, bench: bench, captain: c, viceCaptain: v);
  }

  static Lineup _build(
    Formation target, {
    required List<int> preference,
    required List<int> previousBench,
    int? captain,
    int? viceCaptain,
  }) {
    final counts = {'GK': 1, 'DEF': target.def, 'MID': target.mid, 'FWD': target.fwd};
    final starters = <int>[
      for (final MapEntry(key: role, value: n) in counts.entries)
        ...preference.where((s) => footballSquadRoles[s] == role).take(n),
    ]..sort();

    // Backup keeper first, then outfielders in their previous bench order,
    // with newly dropped starters last.
    int rank(int s) {
      final i = previousBench.indexOf(s);
      return i == -1 ? 100 + s : i;
    }

    final benched = [for (var s = 0; s < footballSquadRoles.length; s++) if (!starters.contains(s)) s];
    final outfield = benched.where((s) => footballSquadRoles[s] != 'GK').toList()
      ..sort((a, b) => rank(a).compareTo(rank(b)));
    return Lineup(
      starters: starters,
      bench: [...benched.where((s) => footballSquadRoles[s] == 'GK'), ...outfield],
    )._withArmbands(captain, viceCaptain);
  }

  @override
  List<Object?> get props => [starters, bench, captain, viceCaptain];
}

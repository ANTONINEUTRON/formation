import 'package:equatable/equatable.dart';

/// Football is 11 starters: the formation decides how many defenders,
/// midfielders and forwards. There's no bench, because stocks are always
/// tradable. Mirrors `backend/src/domain/sport.ts`.
class Formation extends Equatable {
  const Formation(this.def, this.mid, this.fwd);

  factory Formation.parse(String name) {
    final parts = name.split('-').map(int.parse).toList();
    return Formation(parts[0], parts[1], parts[2]);
  }

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

const defaultFormation = '4-4-2';

/// Every formation the backend accepts.
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

/// Roles in slot order for a formation: GK, defenders, midfielders, forwards.
List<String> footballRoles(String formation) {
  final f = Formation.parse(formation);
  return [
    'GK',
    ...List.filled(f.def, 'DEF'),
    ...List.filled(f.mid, 'MID'),
    ...List.filled(f.fwd, 'FWD'),
  ];
}

/// What a formation change will do, so the app can confirm before saving.
/// Mirrors `remapFormation` in `backend/src/domain/formation.ts`.
class FormationPreview {
  const FormationPreview({required this.kept, required this.dropped});

  /// Slot index in the new shape → the mint that moves there.
  final Map<int, String> kept;

  /// Mints that no longer fit; still owned, just off the team.
  final List<String> dropped;
}

FormationPreview previewFormationChange({
  required String from,
  required String to,
  /// Current picks by slot index.
  required Map<int, String> picks,
}) {
  final fromRoles = footballRoles(from);
  final toRoles = footballRoles(to);

  final byRole = <String, List<String>>{};
  for (final slot in picks.keys.toList()..sort()) {
    final role = fromRoles[slot];
    byRole.putIfAbsent(role, () => []).add(picks[slot]!);
  }

  final kept = <int, String>{};
  final taken = <String>{};
  for (var slot = 0; slot < toRoles.length; slot++) {
    final queue = byRole[toRoles[slot]];
    if (queue == null || queue.isEmpty) continue;
    final mint = queue.removeAt(0);
    kept[slot] = mint;
    taken.add(mint);
  }

  return FormationPreview(
    kept: kept,
    dropped: [for (final mint in picks.values) if (!taken.contains(mint)) mint],
  );
}

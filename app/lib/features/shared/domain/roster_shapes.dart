import 'package:flutter/painting.dart';

import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Position slots for each sport mode, in roster order.
///
/// Board positions are normalized (0..1) with the attacking end at the top.
/// Slot order is the contract with the backend: slot index i in the API is
/// `rosterShape(mode)[i]`.
List<PositionSlot> rosterShape(SportMode mode) => switch (mode) {
      SportMode.basketball => _basketball,
      SportMode.football => _football,
      SportMode.americanFootball => _americanFootball,
    };

Roster emptyRoster(SportMode mode) => Roster(
      mode: mode,
      slots: [for (final p in rosterShape(mode)) RosterSlot(position: p)],
      lineup: mode == SportMode.football ? Lineup.defaultFootball() : null,
    );

/// Where each slot sits on the board. Football lays starters out in rows by
/// formation and returns null for substitutes; other sports are fixed.
List<Offset?> boardLayout(Roster roster) {
  final lineup = roster.lineup;
  if (lineup == null) return [for (final s in roster.slots) s.position.boardPosition];

  const rows = {'GK': 0.9, 'DEF': 0.68, 'MID': 0.43, 'FWD': 0.17};
  final layout = List<Offset?>.filled(roster.slots.length, null);
  for (final MapEntry(key: role, value: y) in rows.entries) {
    final row = lineup.starters.where((s) => footballSquadRoles[s] == role).toList();
    for (var i = 0; i < row.length; i++) {
      layout[row[i]] = Offset((i + 1) / (row.length + 1), y);
    }
  }
  return layout;
}

const _basketball = [
  PositionSlot(label: 'PG', requiredTier: RiskTier.growth, boardPosition: Offset(0.5, 0.82)),
  PositionSlot(label: 'SG', requiredTier: RiskTier.growth, boardPosition: Offset(0.18, 0.62)),
  PositionSlot(label: 'SF', requiredTier: RiskTier.balanced, boardPosition: Offset(0.82, 0.62)),
  PositionSlot(label: 'PF', requiredTier: RiskTier.balanced, boardPosition: Offset(0.28, 0.3)),
  PositionSlot(label: 'C', requiredTier: RiskTier.blueChip, boardPosition: Offset(0.72, 0.3)),
];

const _footballRoleTiers = {
  'GK': RiskTier.blueChip,
  'DEF': RiskTier.stable,
  'MID': RiskTier.balanced,
  'FWD': RiskTier.momentum,
};

// FPL squad of 15. Board positions come from the lineup (see boardLayout).
final _football = [
  for (final role in footballSquadRoles)
    PositionSlot(label: role, requiredTier: _footballRoleTiers[role], boardPosition: Offset.zero),
];

// Offensive formation, line of scrimmage around y = 0.45.
const _americanFootball = [
  PositionSlot(label: 'QB', requiredTier: RiskTier.blueChip, boardPosition: Offset(0.5, 0.64)),
  PositionSlot(label: 'RB', requiredTier: RiskTier.growth, boardPosition: Offset(0.38, 0.84)),
  PositionSlot(label: 'RB', requiredTier: RiskTier.balanced, boardPosition: Offset(0.62, 0.84)),
  PositionSlot(label: 'WR', requiredTier: RiskTier.momentum, boardPosition: Offset(0.1, 0.4)),
  PositionSlot(label: 'WR', requiredTier: RiskTier.growth, boardPosition: Offset(0.9, 0.4)),
  PositionSlot(label: 'WR', requiredTier: RiskTier.momentum, boardPosition: Offset(0.26, 0.2)),
  PositionSlot(label: 'TE', requiredTier: RiskTier.stable, boardPosition: Offset(0.74, 0.2)),
  PositionSlot(label: 'FLEX', requiredTier: null, boardPosition: Offset(0.5, 0.4)),
  PositionSlot(label: 'K', requiredTier: RiskTier.stable, boardPosition: Offset(0.5, 0.08)),
];

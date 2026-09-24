import 'package:flutter/painting.dart';

import 'package:formation/features/shared/domain/lineup.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Position slots for each sport mode, in slot order.
///
/// Slot index i here is slot index i in the API (`backend/src/domain/sport.ts`).
/// Board positions are normalized (0..1) with the attacking end at the top.
List<PositionSlot> rosterShape(SportMode mode, [String? formation]) =>
    switch (mode) {
      SportMode.basketball => _basketball,
      SportMode.football => footballShape(formation ?? defaultFormation),
      SportMode.americanFootball => _americanFootball,
    };

Roster emptyRoster(SportMode mode) => Roster(
      mode: mode,
      slots: [for (final p in rosterShape(mode)) RosterSlot(position: p)],
      formation: mode == SportMode.football ? defaultFormation : null,
    );

/// Where each slot sits on the board.
List<Offset?> boardLayout(Roster roster) =>
    [for (final s in roster.slots) s.position.boardPosition];

const _footballRoleTiers = {
  'GK': RiskTier.blueChip,
  'DEF': RiskTier.stable,
  'MID': RiskTier.balanced,
  'FWD': RiskTier.momentum,
};

const _footballRows = {'GK': 0.9, 'DEF': 0.68, 'MID': 0.43, 'FWD': 0.17};

/// The 11 starters of a formation, laid out in rows on the pitch.
List<PositionSlot> footballShape(String formation) {
  final roles = footballRoles(formation);
  final counts = <String, int>{};
  for (final role in roles) {
    counts[role] = (counts[role] ?? 0) + 1;
  }

  final placed = <String, int>{};
  return [
    for (final role in roles)
      () {
        final index = placed[role] = (placed[role] ?? 0) + 1;
        return PositionSlot(
          label: role,
          requiredTier: _footballRoleTiers[role],
          boardPosition: Offset(index / (counts[role]! + 1), _footballRows[role]!),
        );
      }(),
  ];
}

const _basketball = [
  PositionSlot(label: 'PG', requiredTier: RiskTier.growth, boardPosition: Offset(0.5, 0.82)),
  PositionSlot(label: 'SG', requiredTier: RiskTier.growth, boardPosition: Offset(0.18, 0.62)),
  PositionSlot(label: 'SF', requiredTier: RiskTier.balanced, boardPosition: Offset(0.82, 0.62)),
  PositionSlot(label: 'PF', requiredTier: RiskTier.balanced, boardPosition: Offset(0.28, 0.3)),
  PositionSlot(label: 'C', requiredTier: RiskTier.blueChip, boardPosition: Offset(0.72, 0.3)),
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

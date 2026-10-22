import 'package:equatable/equatable.dart';

import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/shared/domain/models.dart';

/// The five Assistant Managers, bundled so a new Manager can pick one during
/// onboarding, before there's a wallet or a server to ask. Ids match the
/// backend's and the asset names.
const presetCharacters = [
  AssistantCharacter(
    id: 'veteran',
    name: 'The Veteran',
    tagline: 'Calm, old-school, protects what you have.',
    style: 'safe',
  ),
  AssistantCharacter(
    id: 'analyst',
    name: 'The Analyst',
    tagline: 'Numbers first. Every call comes with the data.',
    style: 'balanced',
  ),
  AssistantCharacter(
    id: 'maverick',
    name: 'The Maverick',
    tagline: 'Bold, playful, backs momentum.',
    style: 'bold',
  ),
  AssistantCharacter(
    id: 'mentor',
    name: 'The Mentor',
    tagline: 'Encouraging. Explains the rules as you go.',
    style: 'balanced',
  ),
  AssistantCharacter(
    id: 'scout',
    name: 'The Scout',
    tagline: 'Always hunting the next name worth a look.',
    style: 'balanced',
  ),
];

/// One position in a drafted starter squad.
class StarterPick extends Equatable {
  const StarterPick({
    required this.slotIndex,
    required this.position,
    required this.mint,
    required this.symbol,
    required this.name,
    required this.tier,
    required this.priceUsd,
    required this.reason,
    required this.needsPurchase,
    required this.amountUsd,
  });

  factory StarterPick.fromJson(Map<String, dynamic> json) => StarterPick(
    slotIndex: json['slotIndex'] as int,
    position: json['position'] as String,
    mint: json['mint'] as String,
    symbol: json['symbol'] as String,
    name: json['name'] as String,
    tier: RiskTier.fromApi(json['tier'] as String),
    priceUsd: (json['priceUsd'] as num).toDouble(),
    reason: json['reason'] as String? ?? '',
    needsPurchase: json['needsPurchase'] as bool,
    amountUsd: (json['amountUsd'] as num).toDouble(),
  );

  final int slotIndex;
  final String position;
  final String mint;
  final String symbol;
  final String name;
  final RiskTier tier;
  final double priceUsd;
  final String reason;

  /// False when the wallet already holds it.
  final bool needsPurchase;

  /// Dollars to spend on it; 0 when already held.
  final double amountUsd;

  @override
  List<Object?> get props => [slotIndex, mint, amountUsd];
}

/// A lineup the Assistant Manager drafted for a Manager: complete, or as much
/// of it as the budget buys, with the rest left to fill later.
class StarterSquad extends Equatable {
  const StarterSquad({
    required this.mode,
    required this.formation,
    required this.captainSlot,
    required this.viceCaptainSlot,
    required this.picks,
    required this.text,
    required this.budgetUsd,
    required this.skrUsd,
    required this.draftsLeft,
    this.openSlots = 0,
  });

  factory StarterSquad.fromJson(Map<String, dynamic> json) => StarterSquad(
    mode: SportMode.fromApi(json['mode'] as String),
    formation: json['formation'] as String?,
    captainSlot: json['captainSlot'] as int?,
    viceCaptainSlot: json['viceCaptainSlot'] as int?,
    picks: [for (final p in json['picks'] as List) StarterPick.fromJson(p as Map<String, dynamic>)],
    text: json['text'] as String? ?? '',
    budgetUsd: (json['budgetUsd'] as num).toDouble(),
    skrUsd: (json['skrUsd'] as num?)?.toDouble(),
    draftsLeft: json['draftsLeft'] as int? ?? 0,
    openSlots: json['openSlots'] as int? ?? 0,
  );

  final SportMode mode;
  final String? formation;
  final int? captainSlot;
  final int? viceCaptainSlot;
  final List<StarterPick> picks;
  final String text;
  final double budgetUsd;

  /// SKR's dollar price when the squad was drafted; null when SKR isn't offered.
  final double? skrUsd;

  /// Regenerates left.
  final int draftsLeft;

  /// Positions the budget didn't stretch to; 0 for a full squad.
  final int openSlots;

  double get toSpendUsd => picks.fold(0, (sum, p) => sum + p.amountUsd);

  @override
  List<Object?> get props => [mode, formation, captainSlot, viceCaptainSlot, picks, draftsLeft, openSlots];
}

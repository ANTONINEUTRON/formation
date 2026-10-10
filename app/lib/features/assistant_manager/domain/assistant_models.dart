import 'package:equatable/equatable.dart';

import 'package:formation/features/shared/domain/models.dart';

/// How a character is drawn at a given moment. Every pose shares one canvas
/// with the feet on the same line, so switching never makes the figure jump.
enum AssistantPose {
  neutral,
  thinking,
  celebrating,
  concerned;

  static AssistantPose forMood(AssistantMood mood) => switch (mood) {
        AssistantMood.happy => AssistantPose.celebrating,
        AssistantMood.concerned => AssistantPose.concerned,
        AssistantMood.neutral => AssistantPose.neutral,
      };
}

enum AssistantMood {
  neutral,
  happy,
  concerned;

  static AssistantMood fromApi(Object? value) => switch (value) {
        'happy' => AssistantMood.happy,
        'concerned' => AssistantMood.concerned,
        _ => AssistantMood.neutral,
      };
}

/// One of the Assistant Managers. The user is the Manager; this is the coach
/// they pick to advise them.
class AssistantCharacter extends Equatable {
  const AssistantCharacter({
    required this.id,
    required this.name,
    required this.tagline,
    required this.style,
  });

  factory AssistantCharacter.fromJson(Map<String, dynamic> json) => AssistantCharacter(
        id: json['id'] as String,
        name: json['name'] as String,
        tagline: json['tagline'] as String? ?? '',
        style: json['style'] as String? ?? 'balanced',
      );

  final String id;
  final String name;
  final String tagline;

  /// 'safe', 'balanced' or 'bold'.
  final String style;

  /// Asset for [pose]; ids match the files in assets/characters/.
  String image(AssistantPose pose) => 'assets/characters/${id}_${pose.name}.webp';

  @override
  List<Object?> get props => [id];
}

class AssistantProfile extends Equatable {
  const AssistantProfile({
    required this.characterId,
    required this.characters,
    required this.credits,
    required this.available,
  });

  factory AssistantProfile.fromJson(Map<String, dynamic> json) => AssistantProfile(
        characterId: json['characterId'] as String?,
        characters: [
          for (final c in json['characters'] as List)
            AssistantCharacter.fromJson(c as Map<String, dynamic>),
        ],
        credits: (json['credits'] as num).toInt(),
        available: json['available'] as bool? ?? true,
      );

  /// Null until the Manager picks one.
  final String? characterId;
  final List<AssistantCharacter> characters;
  final int credits;

  /// False when the backend has no model configured.
  final bool available;

  AssistantCharacter? get character {
    for (final c in characters) {
      if (c.id == characterId) return c;
    }
    return null;
  }

  AssistantProfile copyWith({String? characterId, int? credits}) => AssistantProfile(
        characterId: characterId ?? this.characterId,
        characters: characters,
        credits: credits ?? this.credits,
        available: available,
      );

  @override
  List<Object?> get props => [characterId, characters, credits, available];
}

/// Where the Manager opened the assistant from. Sent with every message so the
/// answer is about what they're looking at.
class AssistantContext extends Equatable {
  const AssistantContext({required this.mode, this.screen = 'team', this.focusMint});

  final SportMode mode;

  /// 'team', 'draft', 'league', 'leagues', 'stock', 'profile' or 'manager'.
  final String screen;
  final String? focusMint;

  Map<String, dynamic> toJson() => {
        'mode': mode.apiValue,
        'screen': screen,
        if (focusMint != null) 'focus': {'mint': focusMint},
      };

  @override
  List<Object?> get props => [mode, screen, focusMint];
}

/// A move the assistant recommends. Checked by the backend against the real
/// roster before it gets here, but only the Manager can apply it.
sealed class AssistantSuggestion extends Equatable {
  const AssistantSuggestion({required this.reason});

  static AssistantSuggestion? fromJson(Map<String, dynamic> json) {
    final reason = json['reason'] as String? ?? '';
    return switch (json['kind']) {
      'setCaptain' => CaptainSuggestion(
          slotIndex: json['slotIndex'] as int,
          symbol: json['symbol'] as String? ?? '',
          position: json['position'] as String? ?? '',
          vice: json['vice'] as bool? ?? false,
          reason: reason,
        ),
      'fillSlot' => FillSlotSuggestion(
          slotIndex: json['slotIndex'] as int,
          position: json['position'] as String? ?? '',
          mint: json['mint'] as String,
          symbol: json['symbol'] as String,
          needsPurchase: json['needsPurchase'] as bool? ?? false,
          substitutionCost: (json['substitutionCost'] as num?)?.toDouble() ?? 0,
          reason: reason,
        ),
      'setFormation' => FormationSuggestion(formation: json['formation'] as String, reason: reason),
      _ => null,
    };
  }

  final String reason;
}

class CaptainSuggestion extends AssistantSuggestion {
  const CaptainSuggestion({
    required this.slotIndex,
    required this.symbol,
    required this.position,
    required this.vice,
    required super.reason,
  });

  final int slotIndex;
  final String symbol;
  final String position;
  final bool vice;

  @override
  List<Object?> get props => [slotIndex, vice, reason];
}

class FillSlotSuggestion extends AssistantSuggestion {
  const FillSlotSuggestion({
    required this.slotIndex,
    required this.position,
    required this.mint,
    required this.symbol,
    required this.needsPurchase,
    required this.substitutionCost,
    required super.reason,
  });

  final int slotIndex;
  final String position;
  final String mint;
  final String symbol;

  /// The wallet doesn't hold it yet: it has to be bought first.
  final bool needsPurchase;

  /// Points it costs: 0 within today's free substitutions, negative beyond.
  final double substitutionCost;

  @override
  List<Object?> get props => [slotIndex, mint, needsPurchase, substitutionCost, reason];
}

class FormationSuggestion extends AssistantSuggestion {
  const FormationSuggestion({required this.formation, required super.reason});

  final String formation;

  @override
  List<Object?> get props => [formation, reason];
}

enum SuggestionStatus { open, applying, applied, failed }

enum AssistantRole { manager, assistant }

class AssistantMessage extends Equatable {
  const AssistantMessage({
    required this.role,
    required this.text,
    this.mood = AssistantMood.neutral,
    this.suggestions = const [],
    this.statuses = const [],
  });

  final AssistantRole role;
  final String text;
  final AssistantMood mood;
  final List<AssistantSuggestion> suggestions;

  /// One per suggestion, in the same order.
  final List<SuggestionStatus> statuses;

  AssistantMessage withStatus(int index, SuggestionStatus status) => AssistantMessage(
        role: role,
        text: text,
        mood: mood,
        suggestions: suggestions,
        statuses: [for (var i = 0; i < suggestions.length; i++) i == index ? status : statuses[i]],
      );

  Map<String, dynamic> toJson() => {'role': role.name, 'text': text};

  @override
  List<Object?> get props => [role, text, mood, suggestions, statuses];
}

class AssistantReply {
  const AssistantReply({
    required this.text,
    required this.mood,
    required this.suggestions,
    required this.credits,
  });

  factory AssistantReply.fromJson(Map<String, dynamic> json) => AssistantReply(
        text: json['text'] as String,
        mood: AssistantMood.fromApi(json['mood']),
        suggestions: [
          for (final s in json['suggestions'] as List? ?? const [])
            ?AssistantSuggestion.fromJson(s as Map<String, dynamic>),
        ],
        credits: (json['credits'] as num).toInt(),
      );

  final String text;
  final AssistantMood mood;
  final List<AssistantSuggestion> suggestions;
  final int credits;
}

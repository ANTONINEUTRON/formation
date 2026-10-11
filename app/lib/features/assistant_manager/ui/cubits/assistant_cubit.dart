import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

class AssistantState extends Equatable {
  const AssistantState({
    this.profile,
    this.loading = false,
    this.sending = false,
    this.pose = AssistantPose.neutral,
    this.conversations = const {},
    this.error,
    this.outOfCredits = false,
    this.avatarImages = const {},
  });

  final AssistantProfile? profile;

  /// The custom avatar's poses, fetched once per drawing.
  final Map<AssistantPose, Uint8List> avatarImages;
  final bool loading;

  /// A reply is on its way; the character shows its thinking pose.
  final bool sending;
  final AssistantPose pose;

  /// One running conversation per sport, kept for the session.
  final Map<SportMode, List<AssistantMessage>> conversations;
  final String? error;
  final bool outOfCredits;

  List<AssistantMessage> conversation(SportMode mode) => conversations[mode] ?? const [];

  AssistantState copyWith({
    AssistantProfile? profile,
    bool? loading,
    bool? sending,
    AssistantPose? pose,
    Map<SportMode, List<AssistantMessage>>? conversations,
    String? error,
    bool clearError = false,
    bool? outOfCredits,
    Map<AssistantPose, Uint8List>? avatarImages,
  }) => AssistantState(
    profile: profile ?? this.profile,
    loading: loading ?? this.loading,
    sending: sending ?? this.sending,
    pose: pose ?? this.pose,
    conversations: conversations ?? this.conversations,
    error: clearError ? null : error ?? this.error,
    outOfCredits: outOfCredits ?? this.outOfCredits,
    avatarImages: avatarImages ?? this.avatarImages,
  );

  @override
  List<Object?> get props => [
    profile,
    loading,
    sending,
    pose,
    conversations,
    error,
    outOfCredits,
    avatarImages,
  ];
}

/// The Assistant Manager for the whole session.
///
/// Lives above every sport tab so a conversation survives closing the sheet
/// and switching tabs. Applying a suggestion goes through the same repository
/// calls the draft board uses, so the roster screens refresh themselves.
class AssistantCubit extends Cubit<AssistantState> {
  AssistantCubit({required FormationRepository repository})
    : _repository = repository,
      super(const AssistantState());

  final FormationRepository _repository;

  Future<void> load() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final profile = await _repository.getAssistant();
      final drawingChanged = profile.avatarVersion != state.profile?.avatarVersion;
      emit(state.copyWith(profile: profile, loading: false, outOfCredits: profile.credits <= 0));
      if (profile.avatarVersion != null && (drawingChanged || state.avatarImages.isEmpty)) {
        await _loadAvatar();
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: errorText(e)));
    }
  }

  Future<void> _loadAvatar() async {
    final images = <AssistantPose, Uint8List>{};
    for (final pose in AssistantPose.values) {
      images[pose] = await _repository.avatarImage(pose);
    }
    emit(state.copyWith(avatarImages: images));
  }

  /// Draws a custom Assistant Manager from [photo] and switches to it.
  /// Returns an error message, or null on success.
  Future<String?> createAvatar({
    required Uint8List photo,
    required String mimeType,
    required String personality,
    String? name,
  }) async {
    try {
      final credits = await _repository.createAvatar(
        photo: photo,
        mimeType: mimeType,
        personality: personality,
        name: name,
      );
      emit(
        state.copyWith(
          profile: state.profile?.copyWith(credits: credits),
          avatarImages: const {},
        ),
      );
      await load();
      emit(state.copyWith(pose: AssistantPose.celebrating));
      return null;
    } catch (e) {
      return errorText(e);
    }
  }

  Future<void> pickCharacter(String characterId) async {
    try {
      final profile = await _repository.setAssistantCharacter(characterId);
      emit(state.copyWith(profile: profile, pose: AssistantPose.celebrating, clearError: true));
    } catch (e) {
      emit(state.copyWith(error: errorText(e)));
    }
  }

  Future<void> send(AssistantContext context, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sending) return;

    final mode = context.mode;
    final history = [
      ...state.conversation(mode),
      AssistantMessage(role: AssistantRole.manager, text: trimmed),
    ];
    emit(
      state.copyWith(
        conversations: {...state.conversations, mode: history},
        sending: true,
        pose: AssistantPose.thinking,
        clearError: true,
      ),
    );

    try {
      final reply = await _repository.askAssistant(context, history);
      final message = AssistantMessage(
        role: AssistantRole.assistant,
        text: reply.text,
        mood: reply.mood,
        suggestions: reply.suggestions,
        statuses: [for (final _ in reply.suggestions) SuggestionStatus.open],
        cards: reply.cards,
      );
      emit(
        state.copyWith(
          conversations: {
            ...state.conversations,
            mode: [...history, message],
          },
          sending: false,
          pose: AssistantPose.forMood(reply.mood),
          profile: state.profile?.copyWith(credits: reply.credits),
          outOfCredits: reply.credits <= 0,
        ),
      );
    } catch (e) {
      final out = e is AppException && e.code == outOfCreditsCode;
      emit(
        state.copyWith(
          sending: false,
          pose: AssistantPose.concerned,
          error: errorText(e),
          outOfCredits: out ? true : null,
          profile: out ? state.profile?.copyWith(credits: 0) : null,
        ),
      );
    }
  }

  /// Applies suggestion [suggestionIndex] of message [messageIndex].
  /// A stock that must be bought first is handled by the UI, not here.
  Future<void> apply(SportMode mode, int messageIndex, int suggestionIndex) async {
    final messages = state.conversation(mode);
    if (messageIndex >= messages.length) return;
    final message = messages[messageIndex];
    final suggestion = message.suggestions[suggestionIndex];
    _setStatus(mode, messageIndex, suggestionIndex, SuggestionStatus.applying);

    try {
      switch (suggestion) {
        case CaptainSuggestion(:final slotIndex, :final vice):
          final roster = await _repository.getRoster(mode);
          var captain = roster.captainSlot;
          var viceCaptain = roster.viceCaptainSlot;
          if (vice) {
            viceCaptain = slotIndex;
            if (captain == slotIndex) captain = null;
          } else {
            captain = slotIndex;
            if (viceCaptain == slotIndex) viceCaptain = null;
          }
          await _repository.setCaptaincy(mode, captainSlot: captain, viceCaptainSlot: viceCaptain);
        case FillSlotSuggestion(:final slotIndex, :final mint):
          final stock = (await _repository.getXStocks()).firstWhere((s) => s.mint == mint);
          await _repository.fillSlot(mode, slotIndex, stock);
        case FormationSuggestion(:final formation):
          await _repository.setFormation(mode, formation);
      }
      _setStatus(mode, messageIndex, suggestionIndex, SuggestionStatus.applied);
      emit(state.copyWith(pose: AssistantPose.celebrating));
    } catch (e) {
      _setStatus(mode, messageIndex, suggestionIndex, SuggestionStatus.failed);
      emit(state.copyWith(error: errorText(e), pose: AssistantPose.concerned));
    }
  }

  /// Marks a fill as handed over to the buy flow, so it isn't offered twice.
  void handedToPurchase(SportMode mode, int messageIndex, int suggestionIndex) =>
      _setStatus(mode, messageIndex, suggestionIndex, SuggestionStatus.applied);

  /// A purchase went through; [balance] is the new total from the server.
  void creditsBought(int balance) => emit(
    state.copyWith(
      profile: state.profile?.copyWith(credits: balance),
      outOfCredits: balance <= 0,
      pose: AssistantPose.celebrating,
      clearError: true,
    ),
  );

  void clearConversation(SportMode mode) => emit(
    state.copyWith(
      conversations: {...state.conversations, mode: const []},
      pose: AssistantPose.neutral,
      clearError: true,
    ),
  );

  void dismissError() => emit(state.copyWith(clearError: true));

  void _setStatus(SportMode mode, int messageIndex, int suggestionIndex, SuggestionStatus status) {
    final messages = [...state.conversation(mode)];
    messages[messageIndex] = messages[messageIndex].withStatus(suggestionIndex, status);
    emit(state.copyWith(conversations: {...state.conversations, mode: messages}));
  }
}

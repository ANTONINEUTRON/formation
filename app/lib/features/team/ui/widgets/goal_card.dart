import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';
import 'package:formation/features/assistant_manager/ui/widgets/character_view.dart';
import 'package:formation/features/shared/domain/models.dart';

/// "Goal! TSLAx": the Assistant Manager celebrating a goal as it happens.
/// It's provisional, and says so: the daily rollup confirms it.
class GoalCard extends StatelessWidget {
  const GoalCard({required this.event, super.key});

  final LiveEvent event;

  /// Shows the card over the current screen for a few seconds.
  static void show(BuildContext context, LiveEvent event) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    // The card reads the Manager's chosen character from here.
    AssistantCharacter? character;
    try {
      character = context.read<AssistantCubit>().state.profile?.character;
    } on ProviderNotFoundException {
      character = null;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          duration: const Duration(seconds: 5),
          content: _GoalCardBody(event: event, character: character ?? presetCharacters.first),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => _GoalCardBody(event: event, character: presetCharacters.first);
}

class _GoalCardBody extends StatelessWidget {
  const _GoalCardBody({required this.event, required this.character});

  final LiveEvent event;
  final AssistantCharacter character;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 18)],
      ),
      child: Row(
        children: [
          CharacterHead(character: character, pose: AssistantPose.celebrating, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.label}! ${event.symbol}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${formatSignedPoints(event.points)} provisional · confirmed at the end of the day',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return card;
    return card.animate().scale(begin: const Offset(0.9, 0.9), duration: 260.ms, curve: Curves.easeOutBack);
  }
}

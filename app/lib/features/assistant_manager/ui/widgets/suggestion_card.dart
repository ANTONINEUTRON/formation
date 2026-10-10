import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';

/// A move the Assistant Manager recommends, with what it costs before the
/// Manager taps it. Nothing changes until they do.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({required this.suggestion, required this.status, required this.onApply, super.key});

  final AssistantSuggestion suggestion;
  final SuggestionStatus status;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final (icon, title) = switch (suggestion) {
      CaptainSuggestion(:final symbol, :final position, :final vice) => (
        Icons.military_tech_outlined,
        'Make $symbol ($position) ${vice ? 'vice-captain' : 'captain'}',
      ),
      FillSlotSuggestion(:final symbol, :final position) => (Icons.swap_horiz, 'Play $symbol at $position'),
      FormationSuggestion(:final formation) => (Icons.grid_view_outlined, 'Switch to $formation'),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      // A rounded border must be one colour, so the accent is a stripe inside
      // the card rather than a coloured left border.
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: _accent),
              Expanded(
                child: Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 10), child: _body(icon, title)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _accent, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              if (suggestion.reason.isNotEmpty)
                Text(
                  suggestion.reason,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              if (_cost case final cost?)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(cost.$1, style: AppTextStyles.mono(fontSize: 11, color: cost.$2)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Action(status: status, label: _actionLabel, onPressed: onApply),
      ],
    );
  }

  Color get _accent => status == SuggestionStatus.failed ? AppColors.error : AppColors.primary;

  String get _actionLabel => switch (suggestion) {
    FillSlotSuggestion(needsPurchase: true) => 'Buy',
    _ => 'Apply',
  };

  /// What the move costs, said before the Manager commits to it.
  (String, Color)? get _cost => switch (suggestion) {
    FillSlotSuggestion(needsPurchase: true) => ("You'll buy it first", AppColors.info),
    FillSlotSuggestion(:final substitutionCost) when substitutionCost < 0 => (
      'Costs ${(-substitutionCost).toStringAsFixed(0)} pts (substitution)',
      AppColors.warning,
    ),
    FillSlotSuggestion() => ('Free', AppColors.textMuted),
    _ => null,
  };
}

class _Action extends StatelessWidget {
  const _Action({required this.status, required this.label, required this.onPressed});

  final SuggestionStatus status;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      SuggestionStatus.applying => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
      ),
      SuggestionStatus.applied => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 18, color: AppColors.primary),
          SizedBox(width: 4),
          Text(
            'Done',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      SuggestionStatus.failed => TextButton(onPressed: onPressed, child: const Text('Retry')),
      SuggestionStatus.open => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Text(label),
      ),
    };
  }
}

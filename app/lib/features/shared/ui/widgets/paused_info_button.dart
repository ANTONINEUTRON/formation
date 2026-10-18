import 'package:flutter/material.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/assistant_sheet.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/paused.dart';

/// The little orange ⓘ beside a paused stock (one that isn't scoring right
/// now). Tapped, the Assistant Manager explains why, from a written answer:
/// no AI call, no credit.
class PausedInfoButton extends StatelessWidget {
  const PausedInfoButton({required this.onPressed, super.key});

  /// The button for [stock] in [mode], wired to the explanation.
  factory PausedInfoButton.forStock(BuildContext context, XStock stock, SportMode mode, {Key? key}) =>
      PausedInfoButton(key: key, onPressed: () => whyPaused(context, stock, mode));

  /// Usually [whyPaused] for the stock it sits beside.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Not scoring right now. Why?',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
      onPressed: onPressed,
    );
  }
}

/// Opens the Assistant Manager on why [stock] isn't scoring.
void whyPaused(BuildContext context, XStock stock, SportMode mode, {String screen = 'team'}) =>
    showAssistantSheet(
      context,
      AssistantContext(mode: mode, screen: screen, focusMint: stock.mint),
      explain: pausedExplanation(stock),
    );

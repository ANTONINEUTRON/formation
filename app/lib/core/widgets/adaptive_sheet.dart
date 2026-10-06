import 'package:flutter/material.dart';

import 'package:formation/core/layout/breakpoints.dart';
import 'package:formation/core/theme/theme.dart';

/// Shows [builder] the way the window calls for.
///
/// A bottom sheet is right on a phone, where the thumb is at the bottom of the
/// screen and the sheet rises to meet it. In a desktop browser the same sheet
/// is a strip pinned to the bottom edge of a tall window, miles from the
/// pointer and from whatever it was about to act on — so there it becomes a
/// centred dialog instead.
///
/// The content does not change, only its container, which is why every sheet
/// in the app can route through here unmodified.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  if (context.layoutSize.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: builder,
    );
  }

  return showDialog<T>(
    context: context,
    // The sheets were written against a phone's width; letting a dialog grow
    // past that stretches their rows rather than showing more of anything.
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          // Leave the backdrop visible, so it still reads as a layer over the
          // page rather than a second page.
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.85,
        ),
        child: IntrinsicHeight(child: builder(dialogContext)),
      ),
    ),
  );
}

/// Lays out a main pane and an optional detail pane side by side.
///
/// On compact and medium windows only [main] is shown and [detail] is expected
/// to be reached by navigation instead; at [LayoutSize.expanded] the two sit
/// together, which is the whole reason a desktop window is worth having — a
/// leaderboard next to the lineup you are comparing against.
class TwoPane extends StatelessWidget {
  const TwoPane({super.key, required this.main, this.detail});

  final Widget main;

  /// Null means nothing is selected yet; the main pane then takes the width.
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final side = detail;
    if (!context.layoutSize.hasRoomForTwoPanes || side == null) return main;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: main),
        const VerticalDivider(width: 1, color: AppColors.border),
        SizedBox(width: Breakpoints.detailPaneWidth, child: side),
      ],
    );
  }
}

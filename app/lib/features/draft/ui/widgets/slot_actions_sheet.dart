import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/draft/ui/cubits/draft_cubit.dart';
import 'package:formation/features/draft/ui/widgets/stock_picker_sheet.dart';
import 'package:formation/features/shared/domain/models.dart';

class SlotAction {
  const SlotAction({required this.icon, required this.label, required this.onTap, this.detail});

  final IconData icon;
  final String label;

  /// A second line, e.g. what the action costs.
  final String? detail;
  final VoidCallback onTap;
}

/// What taking [slot] off costs: nothing for a pick that isn't scoring (sold,
/// or under the minimum) or in the weekend transfer window, otherwise one of
/// the day's free substitutions, then points.
String takeOffCost(Roster roster, RosterSlot slot) {
  final session = roster.session;
  if (slot.balance <= 0) return 'Free: it is no longer in your wallet';
  if (session == null) return 'Counts as a substitution';
  if (session.transferWindowOpen) return 'Free: the transfer window is open';
  final left = session.freeSubstitutionsLeft;
  if (left > 0) return 'Uses 1 of your $left free substitution${left == 1 ? '' : 's'} today';
  return 'Costs 4 points: no free substitutions left today';
}

/// Player menu: hand out the armband, change the stock in this slot, or take
/// it off and leave the position empty.
class SlotActionsSheet extends StatelessWidget {
  const SlotActionsSheet({
    required this.title,
    required this.subtitle,
    required this.actions,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<SlotAction> actions;

  static Future<void> show(BuildContext context, {required int slotIndex}) {
    final cubit = context.read<DraftCubit>();
    final roster = cubit.state.roster!;
    final slot = roster.slots[slotIndex];
    final stock = slot.stock!;
    final captainLabel =
        cubit.mode == SportMode.football ? 'Make captain (2× points)' : 'Make go-to scorer (1.5×)';

    Future<void> guarded(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) context.showErrorToast(message: errorText(e));
      }
    }

    return showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        void then(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SlotActionsSheet(
          title: stock.symbol,
          subtitle: '${slot.position.label} · ${stock.companyName}',
          actions: [
            if (cubit.mode != SportMode.americanFootball && roster.captainSlot != slotIndex)
              SlotAction(
                icon: Icons.stars,
                label: captainLabel,
                onTap: () => then(() => guarded(() => cubit.makeCaptain(slotIndex))),
              ),
            if (cubit.mode == SportMode.football && roster.viceCaptainSlot != slotIndex)
              SlotAction(
                icon: Icons.star_half,
                label: 'Make vice-captain',
                onTap: () => then(() => guarded(() => cubit.makeViceCaptain(slotIndex))),
              ),
            SlotAction(
              icon: Icons.search,
              label: 'Change stock',
              onTap: () => then(() => StockPickerSheet.show(context, slotIndex: slotIndex)),
            ),
            SlotAction(
              icon: Icons.person_remove_outlined,
              label: 'Take off',
              detail: takeOffCost(roster, slot),
              onTap: () => then(() => guarded(() async {
                    await cubit.takeOff(slotIndex);
                    if (context.mounted) {
                      context.showSuccessToast(message: '${stock.symbol} is off. It stays on your bench.');
                    }
                  })),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final action in actions)
              ListTile(
                leading: Icon(action.icon, color: AppColors.primary),
                title: Text(action.label),
                subtitle: action.detail == null
                    ? null
                    : Text(action.detail!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                onTap: action.onTap,
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Changes apply from the next gameweek.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

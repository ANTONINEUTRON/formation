import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/extensions/context_extensions.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/draft/ui/cubits/draft_cubit.dart';
import 'package:symbians/features/draft/ui/widgets/stock_picker_sheet.dart';
import 'package:symbians/features/shared/domain/models.dart';

class SlotAction {
  const SlotAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Player menu: hand out the armband, or change the stock in this slot.
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

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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

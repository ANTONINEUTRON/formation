import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/extensions/context_extensions.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/core/widgets/empty_state.dart';
import 'package:symbians/core/widgets/loading_indicator.dart';
import 'package:symbians/features/draft/ui/cubits/draft_cubit.dart';
import 'package:symbians/features/draft/ui/cubits/draft_state.dart';
import 'package:symbians/features/draft/ui/widgets/formation_board.dart';
import 'package:symbians/features/draft/ui/widgets/formation_selector.dart';
import 'package:symbians/features/draft/ui/widgets/slot_actions_sheet.dart';
import 'package:symbians/features/draft/ui/widgets/stock_picker_sheet.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Draft a team by tapping positions on the board. For football this is also
/// "Pick team": the formation and the armbands.
///
/// Every change is saved as it's made and applies from the next gameweek.
@RoutePage()
class DraftBoardPage extends StatelessWidget {
  const DraftBoardPage({required this.mode, super.key});

  final SportMode mode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          DraftCubit(repository: context.read<FormationRepository>(), mode: mode)..load(),
      child: BlocBuilder<DraftCubit, DraftState>(
        builder: (context, state) {
          final roster = state.roster;
          final filled = roster?.slots.where((s) => s.isFilled).length ?? 0;
          final total = roster?.slots.length ?? 0;

          return Scaffold(
            appBar: AppBar(
              title: Text('${mode == SportMode.football ? 'Pick team' : 'Draft'} · ${mode.label}'),
              actions: [
                if (roster != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text('$filled/$total',
                          style: AppTextStyles.mono(fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            body: switch (state.status) {
              LoadStatus.failure => EmptyState(
                  icon: Icons.cloud_off,
                  message: state.error ?? 'Could not load the draft.',
                  actionLabel: 'Retry',
                  onAction: context.read<DraftCubit>().load,
                ),
              _ when roster == null => const LoadingIndicator(),
              _ => SafeArea(child: _DraftBody(roster: roster, filled: filled, total: total)),
            },
          );
        },
      ),
    );
  }
}

class _DraftBody extends StatelessWidget {
  const _DraftBody({required this.roster, required this.filled, required this.total});

  final Roster roster;
  final int filled;
  final int total;

  bool get _isFootball => roster.mode == SportMode.football;

  Future<void> _onSlotTap(BuildContext context, int slot) async {
    if (!roster.slots[slot].isFilled || roster.mode == SportMode.americanFootball) {
      await StockPickerSheet.show(context, slotIndex: slot);
      return;
    }
    await SlotActionsSheet.show(context, slotIndex: slot);
  }

  /// Confirms first when a shape change would drop picks.
  Future<void> _onFormationSelected(BuildContext context, Formation formation) async {
    final cubit = context.read<DraftCubit>();
    final drops = cubit.dropsFor(formation);

    if (drops.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Switch to ${formation.name}?'),
          content: Text(
            '${drops.map((s) => s.symbol).join(', ')} '
            '${drops.length == 1 ? 'no longer fits' : 'no longer fit'} the shape and will come off '
            'your team. You keep the stock in your wallet.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Switch to ${formation.name}'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      final dropped = await cubit.setFormation(formation);
      if (context.mounted && dropped.isNotEmpty) {
        context.showInfoToast(
          message: '${dropped.map((s) => s.symbol).join(', ')} came off your team',
        );
      }
    } catch (e) {
      if (context.mounted) context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text(
            _isFootball
                ? 'Tap a player to give out the armband or change the stock. '
                    'The captain scores double; changes apply from the next gameweek.'
                : 'Tap a position. Stocks you hold fill instantly; anything else you can buy here.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        if (_isFootball) ...[
          FormationSelector(
            current: Formation.parse(roster.formation ?? defaultFormation),
            onSelected: (f) => _onFormationSelected(context, f),
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FormationBoard(
                roster: roster,
                onSlotTap: (i) => _onSlotTap(context, i),
              ),
            ),
          ),
        ),
        const _TierLegend(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: () => context.router.maybePop(),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(
              filled == total ? 'Team complete: done' : 'Save & finish later (${total - filled} left)',
            ),
          ),
        ),
      ],
    );
  }
}

class _TierLegend extends StatelessWidget {
  const _TierLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final tier in RiskTier.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: tier.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(tier.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }
}

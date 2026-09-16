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
import 'package:symbians/features/draft/ui/widgets/bench_strip.dart';
import 'package:symbians/features/draft/ui/widgets/formation_board.dart';
import 'package:symbians/features/draft/ui/widgets/formation_selector.dart';
import 'package:symbians/features/draft/ui/widgets/slot_actions_sheet.dart';
import 'package:symbians/features/draft/ui/widgets/stock_picker_sheet.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Draft a roster by tapping positions on the board. For football this is
/// also FPL's "Pick Team": formation, substitutes and armbands.
///
/// Each change is saved as it's made, so leaving mid-draft keeps progress.
@RoutePage()
class DraftBoardPage extends StatelessWidget {
  const DraftBoardPage({required this.mode, super.key});

  final SportMode mode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DraftCubit(repository: context.read<FormationRepository>(), mode: mode)..load(),
      child: BlocBuilder<DraftCubit, DraftState>(
        builder: (context, state) {
          final roster = state.roster;
          final filled = roster?.slots.where((s) => s.isFilled).length ?? 0;
          final total = roster?.slots.length ?? 0;

          return Scaffold(
            appBar: AppBar(
              title: Text('${roster?.lineup != null ? 'Pick team' : 'Draft'} · ${mode.label}'),
              actions: [
                if (roster != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text('$filled/$total', style: AppTextStyles.mono(fontWeight: FontWeight.w700)),
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
              _ => SafeArea(child: _DraftBody(state: state, roster: roster, filled: filled, total: total)),
            },
          );
        },
      ),
    );
  }
}

class _DraftBody extends StatelessWidget {
  const _DraftBody({required this.state, required this.roster, required this.filled, required this.total});

  final DraftState state;
  final Roster roster;
  final int filled;
  final int total;

  Future<void> _onSlotTap(BuildContext context, int slot) async {
    final cubit = context.read<DraftCubit>();
    final substituting = cubit.state.substituting;

    if (substituting != null) {
      if (slot == substituting) {
        cubit.cancelSubstitution();
      } else {
        await _guard(context, () => cubit.substituteWith(slot));
      }
      return;
    }
    if (roster.lineup == null || !roster.slots[slot].isFilled) {
      await StockPickerSheet.show(context, slotIndex: slot);
      return;
    }
    await SlotActionsSheet.show(context, slotIndex: slot);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DraftCubit>();
    final lineup = roster.lineup;
    final substituting = state.substituting;
    final targets = cubit.substitutionTargets();

    return Column(
      children: [
        if (substituting != null)
          _SubstitutionBanner(
            name: roster.slots[substituting].stock?.symbol ?? roster.slots[substituting].position.label,
            onCancel: cubit.cancelSubstitution,
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              lineup == null
                  ? 'Tap a position. Stocks you hold fill instantly; anything else you can buy right here.'
                  : 'Tap a player to substitute, hand out the armband, or change the stock. '
                      'Captain scores double; substitutes come on if a starter is sold.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        if (lineup != null) ...[
          FormationSelector(
            current: lineup.formation,
            onSelected: (f) => _guard(context, () => cubit.setFormation(f)),
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
                selectedSlot: substituting,
                highlightedSlots: targets,
              ),
            ),
          ),
        ),
        if (lineup != null) ...[
          const SizedBox(height: 10),
          BenchStrip(
            roster: roster,
            onSlotTap: (i) => _onSlotTap(context, i),
            selectedSlot: substituting,
            highlightedSlots: targets,
          ),
        ],
        const _TierLegend(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: () => context.router.maybePop(),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(filled == total ? 'Team complete: done' : 'Save & finish later (${total - filled} left)'),
          ),
        ),
      ],
    );
  }
}

Future<void> _guard(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) context.showErrorToast(message: errorText(e));
  }
}

class _SubstitutionBanner extends StatelessWidget {
  const _SubstitutionBanner({required this.name, required this.onCancel});

  final String name;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_vert, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Swap $name with a highlighted player',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
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
                Container(width: 8, height: 8, decoration: BoxDecoration(color: tier.color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(tier.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    );
  }
}

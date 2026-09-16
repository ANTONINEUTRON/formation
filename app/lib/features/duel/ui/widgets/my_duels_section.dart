import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/extensions/context_extensions.dart';
import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/duel/ui/cubits/duel_cubit.dart';
import 'package:symbians/features/duel/ui/cubits/duel_state.dart';
import 'package:symbians/features/duel/ui/widgets/duel_card.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// "My duels" block at the bottom of the Team tab.
class MyDuelsSection extends StatelessWidget {
  const MyDuelsSection({super.key});

  static const _pastLimit = 5;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DuelCubit>();

    Future<void> respond(Duel duel, bool accept) async {
      try {
        await cubit.respond(duel.id, accept: accept);
        if (context.mounted && accept) {
          context.showSuccessToast(message: 'Duel on! Ends in ${formatDuelDuration(duel.duration)}.');
        }
      } catch (e) {
        if (context.mounted) context.showErrorToast(message: errorText(e));
      }
    }

    Widget card(Duel duel, DuelState state) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DuelCard(
            duel: duel,
            isBusy: state.busyDuelId == duel.id,
            onTap: () => context.router.push(DuelDetailRoute(duelId: duel.id, mode: cubit.mode)),
            onAccept: () => respond(duel, true),
            onDecline: () => respond(duel, false),
          ),
        );

    return BlocBuilder<DuelCubit, DuelState>(
      builder: (context, state) {
        final past = state.past.take(_pastLimit).toList();
        final nothing = state.invites.isEmpty && state.active.isEmpty && state.outgoing.isEmpty && past.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Duels', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.router.push(CreateDuelRoute(mode: cubit.mode)),
                  icon: const Icon(Icons.sports_mma, size: 16),
                  label: const Text('Challenge a friend'),
                ),
              ],
            ),
            if (nothing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No duels yet. Challenge anyone from the League tab: whoever\'s '
                  'team performs better over the window wins.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            if (state.invites.isNotEmpty) ...[
              const _Label('Invites'),
              for (final d in state.invites) card(d, state),
            ],
            if (state.active.isNotEmpty) ...[
              const _Label('Live'),
              for (final d in state.active) card(d, state),
            ],
            if (state.outgoing.isNotEmpty) ...[
              const _Label('Waiting for opponent'),
              for (final d in state.outgoing) card(d, state),
            ],
            if (past.isNotEmpty) ...[
              const _Label('Past'),
              for (final d in past) card(d, state),
            ],
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.textMuted),
      ),
    );
  }
}

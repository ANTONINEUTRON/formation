import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/widgets/empty_state.dart';
import 'package:symbians/core/widgets/loading_indicator.dart';
import 'package:symbians/features/duel/ui/widgets/my_duels_section.dart';
import 'package:symbians/features/league/ui/cubits/league_cubit.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/team/ui/cubits/team_cubit.dart';
import 'package:symbians/features/team/ui/cubits/team_state.dart';
import 'package:symbians/features/team/ui/widgets/live_tick_indicator.dart';
import 'package:symbians/features/team/ui/widgets/lineup_section.dart';
import 'package:symbians/features/team/ui/widgets/score_header.dart';

/// Team tab: the user's roster for the page's sport, its score, and duels.
class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeamCubit>();
    void openDraft() => context.router.push(DraftBoardRoute(mode: cubit.mode));

    return BlocBuilder<TeamCubit, TeamState>(
      builder: (context, state) {
        final roster = state.roster;
        if (roster == null) {
          return state.status == LoadStatus.failure
              ? EmptyState(
                  icon: Icons.cloud_off,
                  message: state.error ?? 'Could not load your team.',
                  actionLabel: 'Retry',
                  onAction: cubit.load,
                )
              : const LoadingIndicator();
        }

        if (roster.isEmpty) {
          return EmptyState(
            icon: cubit.mode.icon,
            message:
                'You have no ${cubit.mode.label} team yet.\n'
                'Draft ${roster.slots.length} xStocks into positions to join '
                'the global league and start duelling.',
            actionLabel: 'Draft your team',
            onAction: openDraft,
          );
        }

        final totalPlayers = context.select<LeagueCubit, int>((c) => c.state.entries.length);

        return RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
            children: [
              ScoreHeader(roster: roster, totalPlayers: totalPlayers),
              const SizedBox(height: 8),
              LiveTickIndicator(
                onRunTick: kDebugMode ? cubit.runTick : null,
                isTicking: state.isTicking,
              ),
              if (!roster.isComplete) ...[
                const SizedBox(height: 8),
                _IncompleteBanner(
                  filled: roster.slots.where((s) => s.isFilled).length,
                  total: roster.slots.length,
                  onContinue: openDraft,
                ),
              ],
              const SizedBox(height: 16),
              LineupSection(roster: roster, onEdit: openDraft),
              const SizedBox(height: 16),
              const MyDuelsSection(),
            ],
          ),
        );
      },
    );
  }
}

class _IncompleteBanner extends StatelessWidget {
  const _IncompleteBanner({required this.filled, required this.total, required this.onContinue});

  final int filled;
  final int total;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$filled of $total slots filled. Complete your team to duel.',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          TextButton(onPressed: onContinue, child: const Text('Continue')),
        ],
      ),
    );
  }
}

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
import 'package:symbians/features/team/ui/widgets/gameweek_bar.dart';
import 'package:symbians/features/team/ui/widgets/lineup_section.dart';
import 'package:symbians/features/team/ui/widgets/score_header.dart';

/// Team tab: the user's team for this sport, its gameweek score, and duels.
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
            message: 'You have no ${cubit.mode.label} team yet.\n'
                'Draft ${roster.slots.length} xStocks into positions to join the global league '
                'and start duelling.',
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
              GameweekBar(
                gameweek: roster.gameweek,
                onRunTick: kDebugMode ? cubit.runTick : null,
                onAdvance: kDebugMode ? cubit.advanceGameweek : null,
                isBusy: state.isTicking,
              ),
              if (roster.pendingChanges) ...[
                const SizedBox(height: 8),
                const _Banner(
                  icon: Icons.schedule,
                  color: AppColors.warning,
                  message: 'Your changes apply from the next gameweek. '
                      'This one is scored on the team locked when it opened.',
                ),
              ],
              if (!roster.isComplete) ...[
                const SizedBox(height: 8),
                _Banner(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  message:
                      '${roster.slots.where((s) => s.isFilled).length} of ${roster.slots.length} '
                      'slots filled. Complete your team to score and duel.',
                  action: TextButton(onPressed: openDraft, child: const Text('Continue')),
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, action == null ? 10 : 6, action == null ? 14 : 6, action == null ? 10 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

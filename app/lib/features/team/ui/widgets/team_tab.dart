import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/route/app_route.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/widgets/empty_state.dart';
import 'package:formation/core/widgets/loading_indicator.dart';
import 'package:formation/features/league/ui/cubits/league_cubit.dart';
import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/team/ui/cubits/team_cubit.dart';
import 'package:formation/features/team/ui/cubits/team_state.dart';
import 'package:formation/features/team/ui/widgets/bench_section.dart';
import 'package:formation/features/team/ui/widgets/session_bar.dart';
import 'package:formation/features/team/ui/widgets/lineup_section.dart';
import 'package:formation/features/team/ui/widgets/score_header.dart';

/// Team tab: the user's starting lineup, today's score, and the bench.
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
              SessionBar(
                session: roster.session,
                onRunTick: kDebugMode ? cubit.runTick : null,
                isBusy: state.isTicking,
              ),
              if (!roster.isComplete) ...[
                const SizedBox(height: 8),
                _Banner(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  message:
                      '${roster.slots.where((s) => s.isFilled).length} of ${roster.slots.length} '
                      'slots filled. Complete your team to start scoring.',
                  action: TextButton(onPressed: openDraft, child: const Text('Continue')),
                ),
              ],
              const SizedBox(height: 16),
              LineupSection(roster: roster, onEdit: openDraft),
              const SizedBox(height: 16),
              BenchSection(bench: roster.bench, onSubstitute: (_) => openDraft()),
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

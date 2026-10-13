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
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/team/ui/widgets/goal_card.dart';
import 'package:formation/features/team/ui/widgets/match_week_result_sheet.dart';
import 'package:formation/features/team/ui/widgets/session_bar.dart';
import 'package:formation/features/team/ui/widgets/lineup_section.dart';
import 'package:formation/features/team/ui/widgets/score_header.dart';

/// Provisional goals in [next] that weren't in [previous].
List<LiveEvent> _newGoals(TeamState previous, TeamState next) {
  final seen = {
    for (final e in previous.roster?.session?.liveEvents ?? const <LiveEvent>[])
      if (e.isGoal && e.isProvisional) '${e.mint}:${e.code}:${e.label}',
  };
  return [
    for (final e in next.roster?.session?.liveEvents ?? const <LiveEvent>[])
      if (e.isGoal && e.isProvisional && !seen.contains('${e.mint}:${e.code}:${e.label}')) e,
  ];
}

/// Team tab: the user's starting lineup, today's score, and the bench.
class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeamCubit>();
    void openDraft() => context.router.push(DraftBoardRoute(mode: cubit.mode));

    // A goal that wasn't there on the last load: celebrate it. Goals already on
    // the board when the tab opens aren't news, and don't fire.
    var goals = const <LiveEvent>[];
    return BlocConsumer<TeamCubit, TeamState>(
      listenWhen: (previous, next) {
        goals = _newGoals(previous, next);
        return goals.isNotEmpty;
      },
      listener: (context, state) => GoalCard.show(context, goals.last),
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
                onOpenResult: () => MatchWeekResultSheet.show(
                  context,
                  repository: context.read<FormationRepository>(),
                  mode: cubit.mode,
                ),
                isBusy: state.isTicking,
              ),
              for (final fixture in roster.session?.liveFixtures ?? const <LiveFixture>[]) ...[
                const SizedBox(height: 8),
                _FixtureLine(fixture: fixture),
              ],
              if (!roster.isComplete) ...[
                const SizedBox(height: 8),
                _Banner(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  message: roster.holdsAny
                      ? 'Scoring with ${roster.filledCount} of ${roster.slots.length} picks. '
                          'Fill more slots to score more.'
                      : 'Add a stock you own to your lineup to start scoring.',
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

/// "Office league · you 42.1 – 38.0 ben · live": this week's fixture.
class _FixtureLine extends StatelessWidget {
  const _FixtureLine({required this.fixture});

  final LiveFixture fixture;

  @override
  Widget build(BuildContext context) {
    final lead = fixture.points - fixture.opponentPoints;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.router.push(LeagueDetailRoute(leagueId: fixture.leagueId)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.sports_score, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fixture.leagueName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            if (fixture.opponent == null)
              const Text('Bye this week', style: TextStyle(color: AppColors.textMuted))
            else ...[
              Text(
                'You ${formatPoints(fixture.points)} – ${formatPoints(fixture.opponentPoints)} ${fixture.opponent}',
                style: AppTextStyles.mono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: lead.abs() < 0.5 ? AppColors.textPrimary : pnlColor(lead),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                fixture.isFinal ? 'FT' : 'live',
                style: TextStyle(
                  fontSize: 11,
                  color: fixture.isFinal ? AppColors.textMuted : AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
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

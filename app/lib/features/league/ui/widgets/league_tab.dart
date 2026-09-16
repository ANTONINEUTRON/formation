import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/widgets/empty_state.dart';
import 'package:symbians/core/widgets/loading_indicator.dart';
import 'package:symbians/features/league/ui/cubits/league_cubit.dart';
import 'package:symbians/features/league/ui/cubits/league_state.dart';
import 'package:symbians/features/league/ui/widgets/leaderboard_row.dart';
import 'package:symbians/features/league/ui/widgets/my_rank_banner.dart';
import 'package:symbians/features/shared/domain/load_status.dart';

/// League tab: the global Classic leaderboard for the page's sport mode.
class LeagueTab extends StatelessWidget {
  const LeagueTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LeagueCubit>();

    return BlocBuilder<LeagueCubit, LeagueState>(
      builder: (context, state) {
        if (state.status == LoadStatus.initial ||
            (state.status == LoadStatus.loading && state.entries.isEmpty)) {
          return const LoadingIndicator();
        }
        if (state.status == LoadStatus.failure && state.entries.isEmpty) {
          return EmptyState(
            icon: Icons.cloud_off,
            message: state.error ?? 'Could not load the league.',
            actionLabel: 'Retry',
            onAction: cubit.load,
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: MyRankBanner(
                mode: cubit.mode,
                me: state.me,
                totalPlayers: state.entries.length,
                onDraftTeam: () => DefaultTabController.of(context).animateTo(1),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                  itemCount: state.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final entry = state.entries[i];
                    return LeaderboardRow(
                      entry: entry,
                      onTap: entry.isCurrentUser
                          ? null
                          : () => context.router.push(CreateDuelRoute(
                                mode: cubit.mode,
                                initialOpponent: entry.username,
                              )),
                    )
                        .animate()
                        .fadeIn(delay: (20 * i.clamp(0, 15)).ms)
                        .slideY(begin: 0.1, end: 0);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

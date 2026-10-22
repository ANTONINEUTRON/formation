import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/route/app_route.dart';
import 'package:formation/core/widgets/empty_state.dart';
import 'package:formation/core/widgets/loading_indicator.dart';
import 'package:formation/features/league/ui/cubits/league_cubit.dart';
import 'package:formation/features/league/ui/cubits/league_state.dart';
import 'package:formation/features/league/ui/widgets/leaderboard_row.dart';
import 'package:formation/features/league/ui/widgets/my_rank_banner.dart';
import 'package:formation/features/league/ui/widgets/period_selector.dart';
import 'package:formation/features/league/ui/widgets/rank_move.dart';
import 'package:formation/features/shared/domain/load_status.dart';

/// League tab: the global Classic leaderboard for the page's sport mode.
///
/// When the user's rank has changed since they last looked, their row slides
/// from its old place to the new one and the rows they passed shift the other
/// way. Coming back to the app re-checks, so a move overnight shows on return.
class LeagueTab extends StatefulWidget {
  const LeagueTab({super.key});

  @override
  State<LeagueTab> createState() => _LeagueTabState();
}

class _LeagueTabState extends State<LeagueTab> {
  final _scroll = ScrollController();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => context.read<LeagueCubit>().load(silent: true),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the user's new place into view, a little below the top.
  void _showMove(LeagueState state) {
    final index = state.entries.indexWhere((e) => e.isCurrentUser);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = (index * leaderboardRowExtent - leaderboardRowExtent * 2)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(target, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LeagueCubit>();

    return BlocConsumer<LeagueCubit, LeagueState>(
      listenWhen: (previous, next) => next.rankMove != null && next.rankMove != previous.rankMove,
      listener: (context, state) => _showMove(state),
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

        final move = state.rankMove;
        return Column(
          children: [
            const SizedBox(height: 12),
            PeriodSelector(
              period: state.period,
              onChanged: cubit.setPeriod,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: MyRankBanner(
                mode: cubit.mode,
                me: state.me,
                move: move,
                totalPlayers: state.entries.length,
                onDraftTeam: () => DefaultTabController.of(context).animateTo(1),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView.separated(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                  itemCount: state.entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final entry = state.entries[i];
                    final row = LeaderboardRow(
                      entry: entry,
                      // Tapping a manager opens their profile, where you can
                      // follow them or adopt their wallet.
                      onTap: () => context.router.push(
                        ManagerProfileRoute(
                          userId: entry.userId,
                          mode: cubit.mode,
                          // In the URL too, so a reload or a copied link keeps the sport.
                          modeName: cubit.mode.apiValue,
                        ),
                      ),
                    );

                    if (move != null && entry.isCurrentUser) {
                      return MovedRow(key: ValueKey('moved-${move.serial}'), move: move, child: row);
                    }
                    // Everyone between the old place and the new one moved a
                    // place the other way.
                    final passed = move != null &&
                        (move.isUp
                            ? entry.rank > move.to && entry.rank <= move.from
                            : entry.rank >= move.from && entry.rank < move.to);
                    if (passed) {
                      return ShiftedRow(key: ValueKey('shift-${move.serial}-${entry.userId}'), move: move, child: row);
                    }
                    return row
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

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/route/app_route.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/league/ui/cubits/league_cubit.dart';
import 'package:formation/features/league/ui/widgets/league_tab.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/sport/ui/widgets/formation_app_bar.dart';
import 'package:formation/features/team/ui/cubits/team_cubit.dart';
import 'package:formation/features/team/ui/widgets/team_tab.dart';

/// One nav bar destination per sport: League and Team tabs plus the
/// create-league FAB.
class SportPage extends StatelessWidget {
  const SportPage({required this.mode, super.key});

  final SportMode mode;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<FormationRepository>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LeagueCubit(repository: repository, mode: mode)..load()),
        BlocProvider(create: (_) => TeamCubit(repository: repository, mode: mode)..load()),
      ],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: FormationAppBar(
            title: mode.label,
            bottom: const TabBar(
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              dividerColor: AppColors.border,
              // Icon beside the label rather than above it, so the bar stays
              // one line tall.
              tabs: [
                Tab(child: _TabLabel(icon: Icons.leaderboard_outlined, label: 'League')),
                Tab(child: _TabLabel(icon: Icons.groups_outlined, label: 'Team')),
              ],
            ),
          ),
          body: const TabBarView(children: [LeagueTab(), TeamTab()]),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 85),
            child: FloatingActionButton(
              heroTag: 'leagues-${mode.apiValue}',
              onPressed: () => context.router.push(LeaguesRoute(mode: mode)),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverse,
              tooltip: 'Leagues',
              shape: const CircleBorder(),
              child: const Icon(Icons.group_add),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab label with its icon on the same line.
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/extensions/context_extensions.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/duel/ui/cubits/duel_cubit.dart';
import 'package:symbians/features/league/ui/cubits/league_cubit.dart';
import 'package:symbians/features/league/ui/widgets/league_tab.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/sport/ui/widgets/formation_app_bar.dart';
import 'package:symbians/features/team/ui/cubits/team_cubit.dart';
import 'package:symbians/features/team/ui/widgets/team_tab.dart';

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
        BlocProvider(create: (_) => DuelCubit(repository: repository, mode: mode)..load()),
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
              tabs: [
                Tab(text: 'League', icon: Icon(Icons.leaderboard_outlined, size: 20), iconMargin: EdgeInsets.only(bottom: 2)),
                Tab(text: 'Team', icon: Icon(Icons.groups_outlined, size: 20), iconMargin: EdgeInsets.only(bottom: 2)),
              ],
            ),
          ),
          body: const TabBarView(children: [LeagueTab(), TeamTab()]),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 85),
            child: FloatingActionButton.extended(
              heroTag: 'create-league-${mode.apiValue}',
              onPressed: () => context.showInfoToast(
                message: 'Private leagues are coming soon. For now, everyone plays the global league.',
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverse,
              icon: const Icon(Icons.group_add),
              label: const Text('Create league'),
            ),
          ),
        ),
      ),
    );
  }
}

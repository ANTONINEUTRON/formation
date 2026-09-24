import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/route/app_route.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/empty_state.dart';
import 'package:formation/core/widgets/loading_indicator.dart';
import 'package:formation/features/leagues/ui/cubits/leagues_cubit.dart';
import 'package:formation/features/leagues/ui/cubits/leagues_state.dart';
import 'package:formation/features/leagues/ui/widgets/create_league_sheet.dart';
import 'package:formation/features/leagues/ui/widgets/league_card.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/load_status.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Custom leagues for one sport: the ones you're in, and public ones to join.
@RoutePage()
class LeaguesPage extends StatelessWidget {
  const LeaguesPage({required this.mode, super.key});

  final SportMode mode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaguesCubit(
        repository: context.read<FormationRepository>(),
        mode: mode,
      )..load(),
      child: _LeaguesView(mode: mode),
    );
  }
}

class _LeaguesView extends StatelessWidget {
  const _LeaguesView({required this.mode});

  final SportMode mode;

  Future<void> _join(BuildContext context) async {
    final cubit = context.read<LeaguesCubit>();
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Join with a code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. A1B2C3D4'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      await cubit.join(code: code);
      if (context.mounted) context.showInfoToast(message: 'Joined.');
    } catch (e) {
      if (context.mounted) context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LeaguesCubit>();

    return Scaffold(
      appBar: AppBar(
        title: Text('${mode.label} leagues'),
        actions: [
          IconButton(
            onPressed: () => _join(context),
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Join with a code',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CreateLeagueSheet.show(context, cubit),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        tooltip: 'New league',
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<LeaguesCubit, LeaguesState>(
        builder: (context, state) {
          if (state.status == LoadStatus.initial ||
              (state.status == LoadStatus.loading && state.leagues.isEmpty)) {
            return const LoadingIndicator();
          }
          if (state.status == LoadStatus.failure && state.leagues.isEmpty) {
            return EmptyState(
              icon: Icons.cloud_off,
              message: state.error ?? 'Could not load leagues.',
              actionLabel: 'Retry',
              onAction: cubit.load,
            );
          }
          if (state.leagues.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              message: 'No leagues yet. Create one and share the code, or '
                  'challenge someone head to head.',
            );
          }

          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                if (state.mine.isNotEmpty) ...[
                  const _SectionLabel('Your leagues'),
                  for (final league in state.mine) ...[
                    LeagueCard(
                      league: league,
                      onTap: () => context.router.push(
                        LeagueDetailRoute(leagueId: league.id),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 16),
                ],
                if (state.open.isNotEmpty) ...[
                  const _SectionLabel('Open to join'),
                  for (final league in state.open) ...[
                    LeagueCard(
                      league: league,
                      onTap: () => context.router.push(
                        LeagueDetailRoute(leagueId: league.id),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

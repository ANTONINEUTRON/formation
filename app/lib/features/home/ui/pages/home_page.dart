import 'package:auto_route/auto_route.dart';
import 'package:crystal_navigation_bar/crystal_navigation_bar.dart';
import 'package:flutter/material.dart';

import 'package:formation/core/layout/breakpoints.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/sport/ui/pages/sport_page.dart';
import 'package:formation/gen/assets.gen.dart';

/// Home page - main shell with one navigation destination per sport.
@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _modes = [
    SportMode.football,
    SportMode.basketball,
    SportMode.americanFootball,
  ];

  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // A floating bar across the bottom of a desktop window puts the sport
    // switcher as far from the pointer as the window allows, and reads as a
    // phone app in a browser. A rail keeps it beside the content.
    final useRail = context.layoutSize.hasRoomForTwoPanes;

    final pages = IndexedStack(
      index: _currentIndex,
      children: [for (final mode in _modes) SportPage(mode: mode)],
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: useRail
          ? Row(
              children: [
                _SportRail(
                  modes: _modes,
                  currentIndex: _currentIndex,
                  onSelected: _onTabSelected,
                ),
                Expanded(child: pages),
              ],
            )
          : pages,
      extendBody: !useRail,
      bottomNavigationBar: useRail
          ? null
          : CrystalNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
              borderRadius: 55,
              backgroundColor: AppColors.surface.withValues(alpha: 0.95),
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textMuted,
              splashColor: AppColors.primary.withValues(alpha: 0.1),
              indicatorColor: Colors.transparent,
              margin: EdgeInsets.zero,
              items: [
                for (final mode in _modes)
                  CrystalNavigationBarItem(
                    icon: mode.icon,
                    selectedColor: AppColors.primary,
                    unselectedColor: AppColors.textMuted,
                  ),
              ],
            ),
    );
  }
}

/// Sport switcher for wide windows.
class _SportRail extends StatelessWidget {
  const _SportRail({
    required this.modes,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<SportMode> modes;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      backgroundColor: AppColors.surface,
      // The phone layout carries the brand in the app bar, which the rail
      // sits beside rather than under — so without this the wide layout is
      // the only place Formation never says its own name.
      leading: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        child: Assets.brand.formationLogoNobg.image(
          width: 36,
          height: 36,
          fit: BoxFit.contain,
        ),
      ),
      indicatorColor: AppColors.primary.withValues(alpha: 0.14),
      selectedIconTheme: const IconThemeData(color: AppColors.primary),
      unselectedIconTheme: const IconThemeData(color: AppColors.textMuted),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
      ),
      labelType: NavigationRailLabelType.all,
      destinations: [
        for (final mode in modes)
          NavigationRailDestination(
            icon: Icon(mode.icon),
            // "American Football" wraps to two lines in a rail; the sport is
            // clear enough from the icon beside it.
            label: Text(mode == SportMode.americanFootball ? 'NFL' : mode.label),
          ),
      ],
    );
  }
}

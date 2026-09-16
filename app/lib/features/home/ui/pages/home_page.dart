import 'package:auto_route/auto_route.dart';
import 'package:crystal_navigation_bar/crystal_navigation_bar.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/shared/domain/models.dart';
import 'package:symbians/features/sport/ui/pages/sport_page.dart';

/// Home page - main shell with one bottom navigation tab per sport.
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [for (final mode in _modes) SportPage(mode: mode)],
      ),
      extendBody: true,
      bottomNavigationBar: CrystalNavigationBar(
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

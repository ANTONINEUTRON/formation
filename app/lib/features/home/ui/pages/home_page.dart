import 'package:auto_route/auto_route.dart';
import 'package:crystal_navigation_bar/crystal_navigation_bar.dart';
import 'package:flutter/material.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/features/agent/ui/pages/agent_tab_page.dart';
import 'package:symbians/features/profile/ui/pages/profile_tab_page.dart';
import 'package:symbians/features/strategy/ui/pages/strategy_marketplace_page.dart';

/// Home page - main shell with bottom navigation.
@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    AgentTabPage(),
    StrategyMarketplacePage(),
    ProfileTabPage(),
  ];

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,// == 1 ? 0 : _currentIndex,
        children: _pages,
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
          CrystalNavigationBarItem(
            icon: Icons.smart_toy_outlined,
            selectedColor: AppColors.primary,
            unselectedColor: AppColors.textMuted,
          ),
          CrystalNavigationBarItem(
            icon: Icons.store_outlined,
            selectedColor: AppColors.primary,
            unselectedColor: AppColors.textMuted,
          ),
          CrystalNavigationBarItem(
            icon: Icons.person_outline,
            selectedColor: AppColors.primary,
            unselectedColor: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// lib/screens/main_shell.dart

import 'package:flutter/material.dart';
import '../utils/app_icons.dart';

import '../widgets/pill_nav_bar.dart';
import 'explore_screen.dart';
import 'fractionalize_screen.dart';
import 'home_screen.dart';
import 'nft_marketplace_screen.dart';
import 'yield_screen.dart';

// UI/UX: Controls the app's primary tab structure, selected tab state, and
// bottom navigation appearance/order.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),
    NftMarketplaceScreen(),
    FractionalizeScreen(),
    YieldScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: PillNavBar(
        selectedIndex: _currentIndex,
        onSelect: (i) => setState(() => _currentIndex = i),
        items: const [
          PillNavItem(
            icon: AppIcons.homeOutlined,
            selectedIcon: AppIcons.home,
            label: 'Home',
          ),
          PillNavItem(
            icon: AppIcons.searchOutlined,
            selectedIcon: AppIcons.search,
            label: 'Explore',
          ),
          PillNavItem(
            icon: AppIcons.storefrontOutlined,
            selectedIcon: AppIcons.storefront,
            label: 'Market',
          ),
          PillNavItem(
            icon: AppIcons.addBoxOutlined,
            selectedIcon: AppIcons.addBox,
            label: 'Create',
          ),
          PillNavItem(
            icon: AppIcons.waterDropOutlined,
            selectedIcon: AppIcons.waterDrop,
            label: 'Yield',
          ),
        ],
      ),
    );
  }
}

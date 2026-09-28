// lib/screens/main_shell.dart

import 'package:flutter/material.dart';

import '../widgets/liquid_glass.dart';
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: LiquidGlassNavBar(
          selectedIndex: _currentIndex,
          onSelect: (i) => setState(() => _currentIndex = i),
          items: const [
            LiquidGlassNavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
            ),
            LiquidGlassNavItem(
              icon: Icons.search_outlined,
              selectedIcon: Icons.search,
              label: 'Explore',
            ),
            LiquidGlassNavItem(
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront,
              label: 'Market',
            ),
            LiquidGlassNavItem(
              icon: Icons.add_box_outlined,
              selectedIcon: Icons.add_box,
              label: 'Create',
            ),
            LiquidGlassNavItem(
              icon: Icons.water_drop_outlined,
              selectedIcon: Icons.water_drop,
              label: 'Yield',
            ),
          ],
        ),
      ),
    );
  }
}

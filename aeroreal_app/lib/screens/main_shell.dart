// lib/screens/main_shell.dart

import 'package:flutter/material.dart';

import 'agent_api_screen.dart';
import 'explore_screen.dart';
import 'fractionalize_screen.dart';
import 'home_screen.dart';
import 'nft_marketplace_screen.dart';
import 'settings_screen.dart';
import 'yield_screen.dart';

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
    AgentApiScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF1A1625),
        indicatorColor: const Color(0xFF836EF9).withAlpha(77),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF836EF9)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search, color: Color(0xFF836EF9)),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront, color: Color(0xFF836EF9)),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle, color: Color(0xFF836EF9)),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop, color: Color(0xFF836EF9)),
            label: 'Yield',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy, color: Color(0xFF836EF9)),
            label: 'Agent',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF836EF9)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

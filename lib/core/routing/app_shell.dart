import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_texture_backdrop.dart';

/// Persistent bottom-nav shell for the four primary tabs — Home, Path,
/// Fun, Settings. Wraps go_router's [StatefulShellRoute.indexedStack] so
/// each tab keeps its own scroll/navigation state when switching away
/// and back.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Painted here rather than per screen: one CustomPaint for the
      // whole app, and each tab inherits it simply by leaving its own
      // Scaffold transparent.
      body: AppTextureBackdrop(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route_rounded), label: 'Path'),
          NavigationDestination(icon: Icon(Icons.videogame_asset_outlined), selectedIcon: Icon(Icons.videogame_asset_rounded), label: 'Fun'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

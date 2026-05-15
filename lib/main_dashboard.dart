import 'package:flutter/material.dart';
import 'package:heatshield/l10n/app_localizations.dart';

// The 3 main screens of the app
import 'package:heatshield/screens/history_screen.dart';
import 'package:heatshield/screens/monitor_screen.dart';
import 'package:heatshield/screens/settings_screen.dart';

/// The root navigation shell of the app.
/// Holds the 3 main tabs and manages switching between them.
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  /// Tracks which tab is currently visible (0 = Monitor, 1 = History, 2 = Settings).
  int _selectedIndex = 0;

  /// The 3 main screens — created once and kept alive for the app's lifetime.
  final List<Widget> _screens = const [
    MonitorScreen(),  // Tab 0: Map & real-time heat monitoring
    HistoryScreen(),  // Tab 1: Past exposure logs
    SettingsScreen(), // Tab 2: App configuration & developer tools
  ];

  /// Lazy-load tracker: only MonitorScreen (index 0) is built at startup.
  /// Other screens are built the first time the user navigates to them,
  /// avoiding unnecessary work on launch.
  late final List<bool> _loadedScreens =
      List.generate(_screens.length, (i) => i == 0);

  /// Called when the user taps a bottom nav item.
  /// Updates the active tab and marks it as loaded so it gets built.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _loadedScreens[index] = true; // Trigger build for first-time visits
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps all loaded screens alive in memory,
      // preserving their state (scroll position, data, etc.) when switching tabs.
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(_screens.length, (index) {
          if (_loadedScreens[index]) {
            // Screen has been visited — render it
            return _screens[index];
          }
          // Not yet visited — render an invisible zero-size placeholder
          return const SizedBox.shrink();
        }),
      ),

      // Bottom navigation bar with 3 tabs
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Always show all labels
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal.shade700,   // Active tab color
        unselectedItemColor: Colors.grey.shade600, // Inactive tab color
        backgroundColor: Theme.of(context).cardColor,
        elevation: 8,
        items: [
          // Tab 0 — Monitor / Map
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: AppLocalizations.of(context)!.dashboard, // Localized label
          ),
          // Tab 1 — Exposure History
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: AppLocalizations.of(context)!.history, // Localized label
          ),
          // Tab 2 — Settings
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: AppLocalizations.of(context)!.settings, // Localized label
          ),
        ],
      ),
    );
  }
}

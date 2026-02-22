import 'package:flutter/material.dart';
import 'package:heatshield/screens/devices_screen.dart';
import 'package:heatshield/screens/history_screen.dart';
import 'package:heatshield/screens/monitor_screen.dart';
import 'package:heatshield/screens/settings_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    MonitorScreen(),
    DevicesScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        selectedItemColor: isDark ? Colors.tealAccent : Colors.teal.shade700,
        unselectedItemColor: isDark
            ? Colors.grey.shade400
            : Colors.grey.shade600,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Monitor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.watch_outlined),
            activeIcon: Icon(Icons.watch),
            label: 'Devices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

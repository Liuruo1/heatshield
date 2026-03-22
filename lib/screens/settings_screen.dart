import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heatshield/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _hapticFeedback = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = _prefs?.getBool('pushNotifications') ?? true;
      _hapticFeedback = _prefs?.getBool('hapticFeedback') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme Settings
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Dark Mode',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: const Text('Toggle between dark and light themes'),
              secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: themeProvider.isDarkMode
                    ? Colors.indigoAccent
                    : Colors.orange,
              ),
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
              activeThumbColor: Colors.teal,
            ),
          ),
          const SizedBox(height: 24),

          // Notification Settings
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Push Notifications',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text('Receive critical heat alerts'),
                  secondary: const Icon(Icons.notifications_active_outlined),
                  value: _pushNotifications,
                  onChanged: (value) {
                    setState(() {
                      _pushNotifications = value;
                    });
                    _prefs?.setBool('pushNotifications', value);
                  },
                  activeThumbColor: Colors.teal,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text(
                    'Haptic Feedback',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Vibrate on wrist for nearby smartwatches',
                  ),
                  secondary: const Icon(Icons.vibration),
                  value: _hapticFeedback,
                  onChanged: (value) {
                    setState(() {
                      _hapticFeedback = value;
                    });
                    _prefs?.setBool('hapticFeedback', value);
                  },
                  activeThumbColor: Colors.teal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Application Settings
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Application',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text(
                    'Language',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Text(
                    'English',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text(
                    'About HeatShield',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Text(
                    'v1.0.0',
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

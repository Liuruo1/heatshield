import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heatshield/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:heatshield/services/locale_provider.dart';

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

  /// Retrieves shared preferences (e.g., notification and haptic toggles)
  /// and updates the local state.
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = _prefs?.getBool('pushNotifications') ?? true;
      _hapticFeedback = _prefs?.getBool('hapticFeedback') ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              AppLocalizations.of(context)!.notifications,
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
                  title: Text(
                    AppLocalizations.of(context)!.pushNotifications,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(AppLocalizations.of(context)!.receiveCriticalAlerts),
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
                  title: Text(
                    AppLocalizations.of(context)!.hapticFeedback,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    AppLocalizations.of(context)!.vibrateOnWrist,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              AppLocalizations.of(context)!.application,
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
                  title: Text(
                    AppLocalizations.of(context)!.language,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: DropdownButton<String>(
                    value: Provider.of<LocaleProvider>(context).locale?.languageCode ?? 'en',
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'en',
                        child: Text('English'),
                      ),
                      DropdownMenuItem(
                        value: 'ar',
                        child: Text('العربية'),
                      ),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        Provider.of<LocaleProvider>(context, listen: false)
                            .setLocale(Locale(newValue));
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(
                    AppLocalizations.of(context)!.privacyPolicy,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    AppLocalizations.of(context)!.about,
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

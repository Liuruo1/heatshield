import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heatshield/l10n/app_localizations.dart';
import 'package:heatshield/screens/emergency_reports_screen.dart';
import 'package:heatshield/screens/privacy_policy_screen.dart';
import 'package:provider/provider.dart';
import 'package:heatshield/services/backend_api_service.dart';
import 'package:heatshield/services/locale_provider.dart';
import 'package:heatshield/services/time_provider.dart';
import 'package:heatshield/services/server_connection_notifier.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _hapticFeedback = true;
  bool _isRefreshing = false;
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
    final timeProvider = Provider.of<TimeProvider>(context);

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
                  leading: const Icon(Icons.local_hospital, color: Colors.red),
                  title: const Text(
                    'Emergency Escalation Reports',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EmergencyReportsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(
                    AppLocalizations.of(context)!.privacyPolicy,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
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

          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Testing / Developer Options',
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
                  leading: const Icon(Icons.access_time),
                  title: const Text(
                    'Mock Time of Day',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    timeProvider.isMocking
                        ? 'Mocked to ${TimeOfDay.fromDateTime(timeProvider.now).format(context)}'
                        : 'Using actual system time',
                  ),
                  trailing: timeProvider.isMocking
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          onPressed: () {
                            timeProvider.clearMockTime();
                          },
                        )
                      : null,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (picked != null) {
                      timeProvider.setMockTime(picked);
                    }
                  },
                ),
                const Divider(height: 1),
                // Server IP Override
                ListTile(
                  leading: const Icon(Icons.network_wifi, color: Colors.indigo),
                  title: const Text(
                    'Override Server IP',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text('Current: ${BackendApiService.currentBaseUrl}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    String currentIp = BackendApiService.currentBaseUrl
                        .replaceAll('http://', '')
                        .replaceAll(':8000', '');
                    final controller = TextEditingController(text: currentIp);
                    final newIp = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Enter Server IP'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 192.168.1.5',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, controller.text.trim()),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (newIp != null && newIp.isNotEmpty && newIp != currentIp) {
                      setState(() {
                        BackendApiService.overrideBaseUrl(newIp);
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Server IP updated to $newIp')),
                        );
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                // Turbo Mode — fast-forwards exposure by +5 min per tap
                ListTile(
                  leading: const Icon(Icons.bolt, color: Colors.orange),
                  title: const Text(
                    'Turbo Mode (+5 min exposure)',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    ServerConnectionNotifier.turboAction != null
                        ? 'Tap to add +5 min of simulated sun exposure'
                        : 'Open the Monitor screen first',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: ServerConnectionNotifier.turboAction != null,
                  onTap: () async {
                    final action = ServerConnectionNotifier.turboAction;
                    if (action == null) return;
                    await action();
                  },
                ),
                const Divider(height: 1),
                // Altitude Mocking
                ListTile(
                  leading: const Icon(Icons.height, color: Colors.blueAccent),
                  title: const Text(
                    'Simulate Roof Elevation (+50m)',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    ServerConnectionNotifier.altitudeAction != null
                        ? 'Simulate being on a roof (Unsafe)'
                        : 'Open the Monitor screen first',
                  ),
                  trailing: const Icon(Icons.upload),
                  enabled: ServerConnectionNotifier.altitudeAction != null,
                  onTap: () {
                    final action = ServerConnectionNotifier.altitudeAction;
                    if (action == null) return;
                    action(50.0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🏔️ Simulated Roof Elevation (+50m)'),
                        backgroundColor: Colors.blueAccent,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.vertical_align_bottom, color: Colors.green),
                  title: const Text(
                    'Reset Elevation (Ground)',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    ServerConnectionNotifier.altitudeAction != null
                        ? 'Return to ground level (Safe)'
                        : 'Open the Monitor screen first',
                  ),
                  trailing: const Icon(Icons.download),
                  enabled: ServerConnectionNotifier.altitudeAction != null,
                  onTap: () {
                    final action = ServerConnectionNotifier.altitudeAction;
                    if (action == null) return;
                    action(0.0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🛣️ Reset to Ground Elevation'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                // Refresh from Server — re-syncs zones and weather
                ListTile(
                  leading: _isRefreshing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, color: Colors.teal),
                  title: const Text(
                    'Refresh from Server',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    ServerConnectionNotifier.refreshAction != null
                        ? 'Re-sync zones and weather data'
                        : 'Open the Monitor screen first',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled:
                      !_isRefreshing &&
                      ServerConnectionNotifier.refreshAction != null,
                  onTap: () async {
                    final action = ServerConnectionNotifier.refreshAction;
                    if (action == null) return;
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _isRefreshing = true);
                    try {
                      await action();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('✅ Server data refreshed'),
                            backgroundColor: Colors.teal,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('❌ Refresh failed: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isRefreshing = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heatshield/services/zoneDB_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _hapticFeedback = true;
  bool _isLoadingZones = true;
  SharedPreferences? _prefs;
  final ZoneDbService _zoneDbService = ZoneDbService();
  List<ZonePolygon> _zones = [];

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
    await _loadZones();
  }

  /// Fetches the user's custom and built-in heat zones from the local database.
  Future<void> _loadZones() async {
    setState(() {
      _isLoadingZones = true;
    });

    await _zoneDbService.ensureSeedData();
    await _zoneDbService.syncFromBackend();
    final zones = await _zoneDbService.getZones();

    if (!mounted) return;

    setState(() {
      _zones = zones;
      _isLoadingZones = false;
    });
  }

  /// Removes a specified zone from the database and refreshes the list in the UI.
  Future<void> _deleteZone(ZonePolygon zone) async {
    if (zone.id == null) return;

    await _zoneDbService.deleteZone(zone.id!);
    await _loadZones();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted ${zone.name}')));
  }

  /// Opens a dialog to create a new custom heat zone (shaded or unshaded).
  /// Allows the user to specify zone coordinates, name, and active times.
  Future<void> _showAddZoneDialog() async {
    final nameController = TextEditingController();
    final pointsController = TextEditingController();
    ZoneType selectedType = ZoneType.shaded;
    bool allDay = true;
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 18, minute: 0);

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Zone'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Zone name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ZoneType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Zone type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ZoneType.shaded,
                          child: Text('Shaded'),
                        ),
                        DropdownMenuItem(
                          value: ZoneType.unshaded,
                          child: Text('Unshaded'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pointsController,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Points (lat,lng per line)',
                        hintText:
                            '21.4227,39.8258\n21.4227,39.8265\n21.4222,39.8265',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active all day'),
                      value: allDay,
                      onChanged: (value) {
                        setDialogState(() {
                          allDay = value;
                        });
                      },
                    ),
                    if (!allDay)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  startTime = picked;
                                });
                              },
                              child: Text('Start ${startTime.format(context)}'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (picked == null) return;
                                setDialogState(() {
                                  endTime = picked;
                                });
                              },
                              child: Text('End ${endTime.format(context)}'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final points = _parsePoints(pointsController.text);

                    if (name.isEmpty || points.length < 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a name and at least 3 valid points.',
                          ),
                        ),
                      );
                      return;
                    }

                    final startMinute = allDay
                        ? null
                        : startTime.hour * 60 + startTime.minute;
                    final endMinute = allDay
                        ? null
                        : endTime.hour * 60 + endTime.minute;

                    await _zoneDbService.addZone(
                      ZonePolygon(
                        name: name,
                        type: selectedType,
                        points: points,
                        startMinuteOfDay: startMinute,
                        endMinuteOfDay: endMinute,
                      ),
                    );

                    if (!context.mounted) return;
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true) {
      return;
    }

    await _loadZones();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Zone added.')));
  }

  /// Parses a multi-line string of latitude/longitude coordinates into a list of [LatLng] points.
  List<LatLng> _parsePoints(String raw) {
    final points = <LatLng>[];
    final lines = raw.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(',');
      if (parts.length != 2) continue;
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null) continue;
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  String _zoneTypeLabel(ZoneType type) {
    return type == ZoneType.shaded ? 'Shaded' : 'Unshaded';
  }

  Color _zoneTypeColor(ZoneType type) {
    return type == ZoneType.shaded ? Colors.teal : Colors.redAccent;
  }

  Future<void> _confirmDeleteZone(ZonePolygon zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Zone'),
          content: Text('Delete "${zone.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteZone(zone);
    }
  }

  /// Builds the UI section for managing active heat zones, including showing
  /// existing zones and providing a button to add new ones.
  Widget _buildZoneManagementCard() {
    if (_isLoadingZones) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.add_location_alt_outlined),
            title: const Text(
              'Add Zone',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Create your own shaded/unshaded zone'),
            trailing: const Icon(Icons.add),
            onTap: _showAddZoneDialog,
          ),
          if (_zones.isNotEmpty) const Divider(height: 1),
          ..._zones.map((zone) {
            return Column(
              children: [
                ListTile(
                  leading: Icon(Icons.place, color: _zoneTypeColor(zone.type)),
                  title: Text(
                    zone.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${_zoneTypeLabel(zone.type)} • ${zone.points.length} pts • ${zone.activeWindowLabel}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDeleteZone(zone),
                  ),
                ),
                if (_zones.last != zone) const Divider(height: 1),
              ],
            );
          }),
          if (_zones.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                'No custom zones yet. Add one to start.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
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
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Zone Management',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
          ),
          _buildZoneManagementCard(),
          const SizedBox(height: 24),
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

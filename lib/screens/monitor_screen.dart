import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:heatshield/services/geofencing_service.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final MapController _mapController = MapController();
  final GeofenceService _geofenceService = GeofenceService();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationAlways.request();
    if (status.isGranted) {
      if (mounted) {
        _geofenceService.initialize(
          onAlert: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'WARNING: You are entering a Heat Stress Zone!',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _geofenceService.dispose();
    super.dispose();
  }

  // Placeholder location for the Holy Mosque, Makkah
  static const LatLng _initialPosition = LatLng(21.4225, 39.8262);

  // Mock Shaded Zones (Green)
  final List<Polygon> _polygons = [
    Polygon(
      points: const [
        LatLng(21.4227, 39.8258),
        LatLng(21.4227, 39.8265),
        LatLng(21.4222, 39.8265),
        LatLng(21.4222, 39.8258),
      ],
      borderStrokeWidth: 2,
      borderColor: Colors.teal.withValues(alpha: 0.8),
      color: Colors.teal.withValues(alpha: 0.3),
    ),
    // Mock Unshaded Zones (Red)
    Polygon(
      points: const [
        LatLng(21.4230, 39.8266),
        LatLng(21.4230, 39.8275),
        LatLng(21.4220, 39.8275),
        LatLng(21.4220, 39.8266),
      ],
      borderStrokeWidth: 2,
      borderColor: Colors.redAccent.withValues(alpha: 0.8),
      color: Colors.redAccent.withValues(alpha: 0.3),
    ),
    // New Unshaded Zone
    Polygon(
      points: const [
        LatLng(21.42294, 39.82456),
        LatLng(21.42409, 39.82163),
        LatLng(21.42350, 39.82128),
        LatLng(21.42141, 39.82274),
      ],
      borderStrokeWidth: 2,
      borderColor: Colors.redAccent.withValues(alpha: 0.8),
      color: Colors.redAccent.withValues(alpha: 0.3),
    ),
  ];

  // Mock state variables
  bool _showHeatWarning = true;
  bool _isDashboardExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HeatShield Monitor'),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Stack(
        children: [
          // 1. Flutter Map Background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialPosition,
              initialZoom: 17.5,
              onTap: (tapPosition, point) {
                // Print the latitude and longitude when the user taps the map
                final lat = point.latitude.toStringAsFixed(5);
                final lng = point.longitude.toStringAsFixed(5);
                debugPrint('Tapped: $lat, $lng');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Coordinates: $lat, $lng'),
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(label: 'OK', onPressed: () {}),
                  ),
                );
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.heatshield',
              ),
              PolygonLayer(polygons: _polygons),
            ],
          ),

          // 2. High-Priority Heat Warning Alert
          if (_showHeatWarning)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildHeatWarningAlert(),
            ),

          // 3. Status Dashboard (Bottom floating panel)
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: _buildStatusDashboard(context),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildHeatWarningAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.redAccent, width: 2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'CRITICAL HEAT RISK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'You have been in direct sunlight for too long. Seek shade immediately.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54),
            onPressed: () {
              setState(() {
                _showHeatWarning = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDashboard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black12,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Status Dashboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isDashboardExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                ),
                onPressed: () {
                  setState(() {
                    _isDashboardExpanded = !_isDashboardExpanded;
                  });
                },
              ),
            ],
          ),
          if (_isDashboardExpanded) const SizedBox(height: 16),
          if (_isDashboardExpanded)
            // Top Row: Temp & Exposure Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricItem(
                  context,
                  icon: Icons.thermostat_rounded,
                  iconColor: Colors.orange,
                  label: 'Current Temp',
                  value: '48°C',
                  valueColor: Colors.red.shade800,
                ),
                _buildMetricItem(
                  context,
                  icon: Icons.timer_outlined,
                  iconColor: Colors.blueGrey,
                  label: 'Sun Exposure',
                  value: '14 min',
                  valueColor:
                      Theme.of(context).textTheme.bodyLarge?.color ??
                      Colors.black87,
                ),
              ],
            ),
          if (_isDashboardExpanded) const SizedBox(height: 24),

          if (_isDashboardExpanded) // Risk Level Meter
            _buildRiskMeter(context),
          if (_isDashboardExpanded) const SizedBox(height: 24),

          if (_isDashboardExpanded) // Action Buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Routing to nearest shaded zone...'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions_walk, size: 24),
                      label: const Text(
                        'Nearest Safe Zone',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              icon: const Icon(
                                Icons.emergency,
                                color: Colors.red,
                                size: 48,
                              ),
                              title: const Text(
                                'Emergency SOS',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              content: const Text(
                                'Are you sure you want to call Emergency Services?',
                                textAlign: TextAlign.center,
                              ),
                              actionsAlignment: MainAxisAlignment.center,
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text(
                                          'Calling Emergency Services...',
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Call Now'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.emergency),
                      label: const Text('SOS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? iconColor.withValues(alpha: 0.2)
                : iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color:
                    Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7) ??
                    Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskMeter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Risk Level',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const Text(
              'CRITICAL',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(flex: 1, child: Container(color: Colors.amber)),
              const SizedBox(width: 2),
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(
            left: 200.0,
          ), // Mocking indicator position
          child: Icon(
            Icons.arrow_drop_up,
            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            size: 24,
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:heatshield/services/geofencing_service.dart';
import 'package:heatshield/services/history_service.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final MapController _mapController = MapController();
  final GeofenceService _geofenceService = GeofenceService();

  LatLng? _currentLocation =
      _initialPosition; // Initialize so the button is always visible
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isInShadedArea = false;
  bool _isFollowingLocation = true;
  List<LatLng> _routePoints = [];
  String _currentTemp = '--°C';
  int? _currentTempValue;
  Timer? _weatherTimer;
  Timer? _exposureTimer;
  int _exposureSeconds = 0;
  int? _maxTempDuringExposure;
  double _maxRiskDuringExposure = 0.0;

  @override
  void initState() {
    super.initState();
    _checkInitialLocation();
    _requestLocationPermission();
    _fetchWeather();
    // Update weather every 15 minutes
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _fetchWeather(),
    );
  }

  Future<void> _fetchWeather() async {
    try {
      // Coordinates for Makkah
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=21.4225&longitude=39.8262&current=temperature_2m',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['current']['temperature_2m'];
        if (mounted) {
          setState(() {
            _currentTempValue = temp.round();
            _currentTemp = '$_currentTempValue°C';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
  }

  void _checkInitialLocation() {
    if (_currentLocation != null) {
      bool inShaded = false;
      for (int i = 0; i < 2; i++) {
        if (_isPointInPolygon(_currentLocation!, _polygons[i].points)) {
          inShaded = true;
          break;
        }
      }
      _isInShadedArea = inShaded;
      _updateExposureTimer(inShaded);
    }
  }

  void _updateExposureTimer(bool inShaded) {
    if (inShaded) {
      if (_exposureSeconds > 5) {
        Provider.of<HistoryService>(context, listen: false).logIncident(
          durationSeconds: _exposureSeconds,
          maxTemp: _maxTempDuringExposure,
          maxRiskRatio: _maxRiskDuringExposure,
        );
      }
      _exposureTimer?.cancel();
      _exposureTimer = null;
      _exposureSeconds = 0;
      _maxTempDuringExposure = null;
      _maxRiskDuringExposure = 0.0;
    } else {
      _exposureTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _exposureSeconds++;
            double currentRisk = _calculateRiskRatio();

            if (_currentTempValue != null) {
              _maxTempDuringExposure = _maxTempDuringExposure == null
                  ? _currentTempValue
                  : math.max(_maxTempDuringExposure!, _currentTempValue!);
            }
            _maxRiskDuringExposure = math.max(
              _maxRiskDuringExposure,
              currentRisk,
            );

            // Over 15 minutes of unshaded exposure or high risk triggers warning.
            if (_exposureSeconds > 15 * 60 || currentRisk >= 0.8) {
              _showHeatWarning = true;
            }
          });
        }
      });
    }
  }

  String get _formattedExposure {
    if (_exposureSeconds == 0) return '0 min';
    final minutes = _exposureSeconds ~/ 60;
    final seconds = _exposureSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  double _calculateRiskRatio() {
    double tempRisk = 0.0;
    if (_currentTempValue != null) {
      // Temp between 30 and 50 maps to 0.0 -> 0.5
      tempRisk = ((_currentTempValue! - 30) / 20).clamp(0.0, 0.5);
    }
    // Exposure from 0 to 15 mins (900s) maps to 0.0 -> 0.5
    double expRisk = (_exposureSeconds / 900).clamp(0.0, 0.5);

    return (tempRisk + expRisk).clamp(0.0, 1.0);
  }

  String _getRiskLevelText(double ratio) {
    if (ratio < 0.33) return 'LOW';
    if (ratio < 0.66) return 'MODERATE';
    return 'CRITICAL';
  }

  Color _getRiskColor(double ratio) {
    if (ratio < 0.33) return Colors.green;
    if (ratio < 0.66) return Colors.amber.shade700;
    return Colors.red;
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationAlways.request();
    if (status.isGranted) {
      if (mounted) {
        _startLocationTracking();
        _geofenceService.initialize(
          onAlert: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'WARNING: You are entering a Heat Stress Zone!!',
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

  void _startLocationTracking() {
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          if (!mounted) return;
          final newLoc = LatLng(position.latitude, position.longitude);

          // Check if inside any shaded area
          bool inShaded = false;
          // We know the first two polygons are shaded (teal)
          for (int i = 0; i < 2; i++) {
            if (_isPointInPolygon(newLoc, _polygons[i].points)) {
              inShaded = true;
              break;
            }
          }

          setState(() {
            _currentLocation = newLoc;
            _isInShadedArea = inShaded;
            _updateExposureTimer(inShaded);
            if (inShaded) {
              _routePoints.clear();
            } else if (_routePoints.isNotEmpty) {
              _routePoints[0] = newLoc;
            }
          });
        });
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool isInside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude)) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        isInside = !isInside;
      }
    }
    return isInside;
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _geofenceService.dispose();
    _weatherTimer?.cancel();
    _exposureTimer?.cancel();
    super.dispose();
  }

  // Placeholder location for the Holy Mosque, Makkah
  static const LatLng _initialPosition = LatLng(21.42171, 39.82482);

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
    // New Shaded Zone (Green) from user taps
    Polygon(
      points: const [
        LatLng(21.42223, 39.82397),
        LatLng(21.42175, 39.82387),
        LatLng(21.42087, 39.82449),
        LatLng(21.42078, 39.82499),
        LatLng(21.42115, 39.82559),
        LatLng(21.42191, 39.82580),
        LatLng(21.42248, 39.82542),
        LatLng(21.42259, 39.82455),
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
  bool _showHeatWarning = false;
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
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isFollowingLocation) {
                  setState(() {
                    _isFollowingLocation = false;
                  });
                }
              },
              onTap: (tapPosition, point) {
                // Update current fake location
                bool inShaded = false;
                for (int i = 0; i < 2; i++) {
                  if (_isPointInPolygon(point, _polygons[i].points)) {
                    inShaded = true;
                    break;
                  }
                }

                setState(() {
                  _currentLocation = point;
                  _isInShadedArea = inShaded;
                  _updateExposureTimer(inShaded);
                  _isFollowingLocation = false;
                  if (inShaded) {
                    _routePoints.clear();
                  } else if (_routePoints.isNotEmpty) {
                    _routePoints[0] = point;
                  }
                });

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
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 40,
                      height: 40,
                      child: const Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 24),
                          Icon(
                            Icons.circle,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

          // 4. Center on User Location FAB
          if (_currentLocation != null)
            Positioned(
              right: 16,
              top: _showHeatWarning
                  ? 120
                  : 16, // Place below the heat warning if it's showing
              child: FloatingActionButton(
                heroTag: 'center_map',
                backgroundColor: Theme.of(context).cardColor,
                foregroundColor: _isFollowingLocation
                    ? Colors.blue
                    : Colors.teal.shade600,
                elevation: 4,
                onPressed: () {
                  setState(() {
                    _isFollowingLocation = true;
                    _mapController.move(_currentLocation!, 17.5);
                  });
                },
                child: Icon(
                  _isFollowingLocation
                      ? Icons.my_location
                      : Icons.location_searching,
                ),
              ),
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
              if (_currentLocation != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isInShadedArea
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isInShadedArea
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: _isInShadedArea
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isInShadedArea ? 'Shaded' : 'Unshaded',
                        style: TextStyle(
                          color: _isInShadedArea
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
                  value: _currentTemp,
                  valueColor: Colors.red.shade800,
                ),
                _buildMetricItem(
                  context,
                  icon: Icons.timer_outlined,
                  iconColor: Colors.blueGrey,
                  label: 'Sun Exposure',
                  value: _formattedExposure,
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
                        if (_currentLocation == null) return;
                        if (_isInShadedArea) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You are already in a safe shaded zone.'),
                            ),
                          );
                          return;
                        }

                        LatLng? nearestPoint;
                        double minDistance = double.infinity;
                        final distance = const Distance();

                        // Shaded zones are the first two polygons
                        for (int i = 0; i < 2; i++) {
                          for (var point in _polygons[i].points) {
                            final dist = distance.distance(_currentLocation!, point);
                            if (dist < minDistance) {
                              minDistance = dist;
                              nearestPoint = point;
                            }
                          }
                        }

                        if (nearestPoint != null) {
                          setState(() {
                            _routePoints = [_currentLocation!, nearestPoint!];
                            _isFollowingLocation = false;
                          });
                          
                          _mapController.move(nearestPoint, 17.5);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Routing to nearest shaded zone...'),
                            ),
                          );
                        }
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
    final double riskRatio = _calculateRiskRatio();
    final String riskText = _getRiskLevelText(riskRatio);
    final Color riskColor = _getRiskColor(riskRatio);

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
            Text(
              riskText,
              style: TextStyle(
                color: riskColor,
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
        LayoutBuilder(
          builder: (context, constraints) {
            final indicatorPosition = riskRatio * (constraints.maxWidth - 24);
            return Padding(
              padding: EdgeInsets.only(left: indicatorPosition),
              child: Icon(
                Icons.arrow_drop_up,
                color:
                    Theme.of(context).textTheme.bodyLarge?.color ??
                    Colors.black,
                size: 24,
              ),
            );
          },
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:heatshield/services/backend_api_service.dart';
import 'package:heatshield/services/geofencing_service.dart';
import 'package:heatshield/services/history_service.dart';
import 'package:heatshield/services/zoneDB_service.dart';
import 'package:heatshield/services/watch_companion_service.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final MapController _mapController = MapController();
  final GeofenceService _geofenceService = GeofenceService();
  final ZoneDbService _zoneDbService = ZoneDbService();

  // --- State Variables ---
  LatLng? _currentLocation =
      _initialPosition; // Initialize so the button is always visible
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isInShadedArea = false;
  bool _isFollowingLocation = true;
  List<LatLng> _routePoints = [];
  String _currentTemp = '--°C';
  int? _currentTempValue;
  Timer? _weatherTimer;
  Timer? _thresholdTimer;
  Timer? _exposureTimer;
  Timer? _zoneRefreshTimer;
  Timer? _watchSyncTimer;
  StreamSubscription<void>? _zoneUpdatesSubscription;
  int _exposureSeconds = 0;
  int? _maxTempDuringExposure;
  double _maxRiskDuringExposure = 0.0;
  bool _zonesReady = false;
  int _safeExposureSeconds = 15 * 60;
  List<ZonePolygon> _zones = [];
  List<ZonePolygon> _activeZones = [];
  List<Polygon> _polygons = [];
  static const String _adaptiveUserId = 'default';

  // Alharam Zone functionality
  bool _isInAlharam = false;
  final List<LatLng> _alharamZonePoints = const [
    LatLng(21.42713, 39.82618),
    LatLng(21.42575, 39.82734),
    LatLng(21.42517, 39.82924),
    LatLng(21.42365, 39.82963),
    LatLng(21.42111, 39.82782),
    LatLng(21.42023, 39.82702),
    LatLng(21.41996, 39.82486),
    LatLng(21.42048, 39.82362),
    LatLng(21.41880, 39.82317),
    LatLng(21.41888, 39.82279),
    LatLng(21.42043, 39.82265),
    LatLng(21.42269, 39.82182),
    LatLng(21.42413, 39.82161),
  ];

  @override
  void initState() {
    super.initState();
    _zoneUpdatesSubscription = ZoneDbService.updates.listen((_) {
      _loadZones();
    });
    _zoneRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _applyActiveZones(),
    );
    // Sync heat status to watch every second
    _watchSyncTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncHeatStatusToWatch(),
    );
    _loadZones();
    _requestLocationPermission();
    _fetchWeather();
    _refreshAdaptiveThreshold();
    _thresholdTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshAdaptiveThreshold(),
    );
    // Update weather every 15 minutes
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _fetchWeather(),
    );
  }

  /// Syncs the current heat status to the watch via the companion service.
  Future<void> _syncHeatStatusToWatch() async {
    await WatchCompanionService.sendHeatStatus(
      temp: _currentTempValue ?? 0,
      exposure: _exposureSeconds,
      risk: _calculateRiskRatio(),
      shaded: _isInShadedArea,
      safeExposureSeconds: _safeExposureSeconds,
    );
  }

  /// Loads heat zones from the local database and ensures initial seed data is present.
  Future<void> _loadZones() async {
    await _zoneDbService.ensureSeedData();
    await _zoneDbService.syncFromBackend();
    final zones = await _zoneDbService.getZones();

    if (!mounted) return;

    setState(() {
      _zones = zones;
      _zonesReady = true;
    });

    _applyActiveZones();
  }

  /// Filters the loaded zones based on current time (finds active zones)
  /// and updates the map polygons and geofenced heat zones.
  void _applyActiveZones() {
    if (!mounted) return;

    final now = DateTime.now();
    final activeZones = _zones
        .where((zone) => zone.isActiveAt(now))
        .toList(growable: false);
    final activePolygons = activeZones
        .map((zone) => zone.toPolygon())
        .toList(growable: false);

    setState(() {
      _activeZones = activeZones;
      _polygons = activePolygons;
    });

    _geofenceService.setHeatZones(
      activeZones
          .where((zone) => zone.type == ZoneType.unshaded)
          .map((zone) => zone.centroid)
          .toList(),
    );

    _checkInitialLocation();
  }

  /// Fetches effective weather from the backend so zone deltas are applied server-side.
  Future<void> _fetchWeather() async {
    try {
      final loc = _currentLocation ?? _initialPosition;
      final weather = await BackendApiService.fetchEffectiveWeather(location: loc);
      if (!mounted) return;

      setState(() {
        _currentTempValue = weather.effectiveTempC.round();
        _currentTemp = '$_currentTempValue°C';
      });
      await _refreshAdaptiveThreshold();
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
  }

  Future<void> _refreshAdaptiveThreshold() async {
    if (_currentTempValue == null) {
      return;
    }

    try {
      final threshold = await BackendApiService.fetchExposureThreshold(
        userId: _adaptiveUserId,
        temp: _currentTempValue!.toDouble(),
        shaded: _isInShadedArea,
      );
      if (!mounted) return;

      setState(() {
        _safeExposureSeconds = threshold.safeExposureSeconds;
      });
    } catch (e) {
      debugPrint('Error fetching adaptive threshold: $e');
    }
  }

  /// Evaluates whether the user's initial location is within any active shaded zone
  /// and updates the exposure tracker accordingly.
  void _checkInitialLocation() {
    if (_currentLocation != null && _zonesReady) {
      bool inShaded = false;
      for (final zone in _activeZones.where((z) => z.type == ZoneType.shaded)) {
        if (_isPointInPolygon(_currentLocation!, zone.points)) {
          inShaded = true;
          break;
        }
      }
      _isInShadedArea = inShaded;
      _isInAlharam = _isPointInPolygon(_currentLocation!, _alharamZonePoints);
      _updateExposureTimer(inShaded);
    }
  }

  /// Manages the timer that tracks how long the user has been exposed to the sun.
  /// If the user enters a shaded zone, logs the incident and resets the timer.
  void _updateExposureTimer(bool inShaded) {
    if (inShaded) {
      if (_exposureSeconds > 5) {
        unawaited(
          _logExposureIncident(
            durationSeconds: _exposureSeconds,
            maxTemp: _maxTempDuringExposure,
            maxRiskRatio: _maxRiskDuringExposure,
            shaded: false,
          ),
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

            // Dynamic threshold from backend training + critical risk fallback.
            if (_exposureSeconds > _safeExposureSeconds || currentRisk >= 0.8) {
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

  /// Calculates a continuous heat risk ratio (0.0 to 1.0) based on current temperature
  /// and duration of continuous sun exposure.
  double _calculateRiskRatio() {
    double tempRisk = 0.0;
    if (_currentTempValue != null) {
      // Temp between 30 and 50 maps to 0.0 -> 0.5
      tempRisk = ((_currentTempValue! - 30) / 20).clamp(0.0, 0.5);
    }
    // Exposure component adapts to backend-personalized threshold.
    double expRisk = (_exposureSeconds / _safeExposureSeconds).clamp(0.0, 0.5);

    return (tempRisk + expRisk).clamp(0.0, 1.0);
  }

  Future<void> _logExposureIncident({
    required int durationSeconds,
    required int? maxTemp,
    required double maxRiskRatio,
    required bool shaded,
  }) async {
    await Provider.of<HistoryService>(context, listen: false).logIncident(
      durationSeconds: durationSeconds,
      maxTemp: maxTemp,
      maxRiskRatio: maxRiskRatio,
    );

    try {
      await BackendApiService.postIncident(
        userId: _adaptiveUserId,
        durationSeconds: durationSeconds,
        maxTemp: maxTemp,
        maxRiskRatio: maxRiskRatio,
        shaded: shaded,
      );
      await _refreshAdaptiveThreshold();
    } catch (e) {
      debugPrint('Error uploading incident: $e');
    }
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

  /// Requests background/foreground location permissions and starts tracking if granted.
  /// Initializes the geofencing service for zone alerts.
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

  /// Listens to the device's location stream to update the user's position on the map
  /// and determine if they have moved into a shaded or unshaded area.
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
          for (final zone in _activeZones.where(
            (z) => z.type == ZoneType.shaded,
          )) {
            if (_isPointInPolygon(newLoc, zone.points)) {
              inShaded = true;
              break;
            }
          }

          setState(() {
            _currentLocation = newLoc;
            _isInShadedArea = inShaded;
            _isInAlharam = _isPointInPolygon(newLoc, _alharamZonePoints);
            _updateExposureTimer(inShaded);
            if (inShaded) {
              _routePoints.clear();
            } else if (_routePoints.isNotEmpty) {
              _routePoints[0] = newLoc;
            }
          });
        });
  }

  /// Standard Ray-Casting algorithm to determine if a given coordinate point
  /// lies within a defined complex polygon.
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) {
      return false;
    }

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
    _zoneUpdatesSubscription?.cancel();
    _zoneRefreshTimer?.cancel();
    _geofenceService.dispose();
    _watchSyncTimer?.cancel();
    _weatherTimer?.cancel();
    _thresholdTimer?.cancel();
    _exposureTimer?.cancel();
    super.dispose();
  }

  // Placeholder location for the Holy Mosque, Makkah
  static const LatLng _initialPosition = LatLng(21.42171, 39.82482);

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
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isInAlharam ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isInAlharam ? Icons.mosque : Icons.location_off,
                    color: _isInAlharam ? Colors.teal.shade700 : Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isInAlharam ? 'Inside Alharam' : 'Outside Alharam',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: _isInAlharam ? Colors.teal.shade800 : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                for (final zone in _activeZones.where(
                  (z) => z.type == ZoneType.shaded,
                )) {
                  if (_isPointInPolygon(point, zone.points)) {
                    inShaded = true;
                    break;
                  }
                }

                setState(() {
                  _currentLocation = point;
                  _isInShadedArea = inShaded;
                  _isInAlharam = _isPointInPolygon(point, _alharamZonePoints);
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

  /// Builds a critical warning UI popup shown when exposure limits are exceeded.
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

  /// Builds the collapsible bottom dashboard displaying real-time metrics, risk meter, and quick actions.
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
                              content: Text(
                                'You are already in a safe shaded zone.',
                              ),
                            ),
                          );
                          return;
                        }

                        LatLng? nearestPoint;
                        double minDistance = double.infinity;
                        final distance = const Distance();

                        for (final zone in _activeZones.where(
                          (z) => z.type == ZoneType.shaded,
                        )) {
                          for (var point in zone.points) {
                            final dist = distance.distance(
                              _currentLocation!,
                              point,
                            );
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
                              content: Text(
                                'Routing to nearest shaded zone...',
                              ),
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

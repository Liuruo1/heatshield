import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:heatshield/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:heatshield/services/backend_api_service.dart';
import 'package:heatshield/services/geofencing_service.dart';
import 'package:heatshield/services/history_service.dart';
import 'package:heatshield/services/server_connection_notifier.dart';
import 'package:heatshield/services/zoneDB_service.dart';
import 'package:heatshield/services/watch_companion_service.dart';
import 'package:heatshield/services/time_provider.dart';

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
  bool _isRefreshingServer = false;

  // Emergency escalation tracking
  int? _criticalRiskStartExposureSeconds; // exposure counter snapshot when critical began
  LatLng? _criticalRiskStartLocation;     // location snapshot when critical began
  bool _emergencyEscalationTriggered = false;
  // Escalates after this many extra seconds in critical risk at the same spot
  // (10 minutes = 600 seconds beyond the safe-exposure limit)
  static const int _escalationThresholdSeconds = 10 * 60;
  // Movement threshold in metres — less than this counts as "not moved"
  static const double _movementThresholdMetres = 10.0;
  bool _debugMode = false;
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

  // Water Points
  final List<LatLng> _waterPoints = const [
    LatLng(21.42237, 39.82528),
    LatLng(21.42355, 39.82592),
    LatLng(21.42313, 39.82712),
    LatLng(21.42165, 39.82668),
    LatLng(21.42034, 39.82462),
    LatLng(21.42263, 39.82274),
    LatLng(21.42364, 39.82338),
    LatLng(21.42454, 39.82410),
    LatLng(21.42526, 39.82524),
    LatLng(21.42542, 39.82624),
    LatLng(21.42489, 39.82685),
    LatLng(21.42269, 39.82770),
    LatLng(21.42407, 39.82697),
    LatLng(21.42100, 39.82702),
    LatLng(21.42522, 39.82802),
  ];

  @override
  void initState() {
    super.initState();
    ServerConnectionNotifier.setRefreshAction(_refreshServerConnection);
    ServerConnectionNotifier.setTurboAction(_applyTurboStep);
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

  TimeProvider? _timeProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tp = Provider.of<TimeProvider>(context);
    if (_timeProvider != tp) {
      _timeProvider?.removeListener(_onTimeChanged);
      _timeProvider = tp;
      _timeProvider?.addListener(_onTimeChanged);
    }
  }

  void _onTimeChanged() {
    if (mounted) {
      _applyActiveZones();
    }
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

  Future<void> _refreshServerConnection() async {
    if (_isRefreshingServer) {
      return;
    }

    _isRefreshingServer = true;
    try {
      await BackendApiService.fetchZones();
      final loc = _currentLocation ?? _initialPosition;
      await _refreshDaylightWindow(loc);
      final weather = await BackendApiService.fetchEffectiveWeather(
        location: loc,
      );

      if (mounted) {
        setState(() {
          _currentTempValue = weather.effectiveTempC.round();
          _currentTemp = '$_currentTempValue°C';
        });
      }

      await _refreshAdaptiveThreshold();
      await _loadZones();
      ServerConnectionNotifier.clearNoConnectionError();
    } catch (e) {
      debugPrint('Server refresh failed: $e');
      rethrow;
    } finally {
      _isRefreshingServer = false;
    }
  }

  Future<void> _refreshDaylightWindow(LatLng location) async {
    try {
      final daylight = await BackendApiService.fetchDaylightWindow(
        location: location,
      );
      ZonePolygon.updateGlobalDayWindow(
        startMinuteOfDay: daylight.startMinuteOfDay,
        endMinuteOfDay: daylight.endMinuteOfDay,
      );
      _applyActiveZones();
    } catch (e) {
      debugPrint('Error fetching daylight window: $e');
    }
  }

  /// Filters the loaded zones based on current time (finds active zones)
  /// and updates the map polygons and geofenced heat zones.
  void _applyActiveZones() {
    if (!mounted) return;

    final now = Provider.of<TimeProvider>(context, listen: false).now;
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
      await _refreshDaylightWindow(loc);
      final weather = await BackendApiService.fetchEffectiveWeather(
        location: loc,
      );
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
  bool get _isNightTime {
    final nowUtc = Provider.of<TimeProvider>(context, listen: false).now.toUtc();
    final nowMinute = nowUtc.hour * 60 + nowUtc.minute;
    return !ZonePolygon.isMinuteInWindow(
      nowMinute,
      ZonePolygon.globalDayStartMinute,
      ZonePolygon.globalDayEndMinute,
    );
  }

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
    if (inShaded || _isNightTime) {
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
      // Reset escalation when user reaches shade
      _criticalRiskStartExposureSeconds = null;
      _criticalRiskStartLocation = null;
      _emergencyEscalationTriggered = false;
    } else {
      _exposureTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          if (_isNightTime) {
            _updateExposureTimer(false);
            return;
          }
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

            // --- Emergency Escalation ---
            // Fires only when ALL conditions are true:
            //  1. Exposure has exceeded the safe limit
            //  2. Risk is CRITICAL (>= 0.66)
            //  3. User has NOT moved more than _movementThresholdMetres from
            //     where they were when the critical state began
            //  4. _escalationThresholdSeconds of EXPOSURE time have elapsed
            //     since the critical window opened (not wall-clock time, so
            //     the turbo debug mode works correctly too)
            final bool isPastLimit = _exposureSeconds > _safeExposureSeconds;
            final bool isCritical = currentRisk >= 0.66;

            if (isPastLimit && isCritical) {
              // Snapshot on first entry into the critical window
              if (_criticalRiskStartExposureSeconds == null) {
                _criticalRiskStartExposureSeconds = _exposureSeconds;
                _criticalRiskStartLocation = _currentLocation;
              }

              // Check whether the user has moved since the critical window opened
              final bool hasNotMoved = _criticalRiskStartLocation == null ||
                  _currentLocation == null ||
                  const Distance().distance(
                        _currentLocation!,
                        _criticalRiskStartLocation!,
                      ) <
                      _movementThresholdMetres;

              final int secondsInCritical =
                  _exposureSeconds - _criticalRiskStartExposureSeconds!;

              if (!_emergencyEscalationTriggered &&
                  hasNotMoved &&
                  secondsInCritical >= _escalationThresholdSeconds) {
                _emergencyEscalationTriggered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _showEmergencyEscalationDialog();
                });
              }

              // If the user moves significantly, reset the clock so they get
              // another grace period from the new position
              if (!hasNotMoved) {
                _criticalRiskStartExposureSeconds = _exposureSeconds;
                _criticalRiskStartLocation = _currentLocation;
                _emergencyEscalationTriggered = false;
              }
            } else {
              // Risk dropped below critical — reset the clock
              _criticalRiskStartExposureSeconds = null;
              _criticalRiskStartLocation = null;
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
    if (_isNightTime) return 0.0;
    
    final now = Provider.of<TimeProvider>(context, listen: false).now;
    final minuteOfDay = now.hour * 60 + now.minute;
    double timeFactor = 0.7;

    if (minuteOfDay >= 360 && minuteOfDay <= 1080) {
      final distanceFromNoon = (minuteOfDay - 720).abs() / 360.0;
      final middayRisk = (1.0 - distanceFromNoon).clamp(0.0, 1.0);
      timeFactor = 0.7 + (middayRisk * 0.6);
    }

    // Exposure is the primary risk driver.
    // At safeExposureSeconds the bar hits 0.8 (alert zone), regardless of temp.
    double expRisk = (_exposureSeconds / _safeExposureSeconds).clamp(0.0, 0.8);

    double tempBonus = 0.0;
    if (_currentTempValue != null) {
      // Temp 30°C → 50°C adds up to 0.2 bonus on top of exposure
      tempBonus = ((_currentTempValue! - 30) / 20).clamp(0.0, 0.2);
    }

    // timeFactor used additively (not as multiplier) so it can't reduce risk below expRisk
    final double timeBonus =
        (timeFactor - 0.7) * 0.1; // 0.0 at off-peak, +0.06 at noon

    return (expRisk + tempBonus + timeBonus).clamp(0.0, 1.0);
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

  String _getRiskLevelText(double ratio, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (ratio < 0.33) return l10n.low;
    if (ratio < 0.66) return l10n.moderate;
    return l10n.critical;
  }

  Color _getRiskColor(double ratio) {
    if (ratio < 0.33) return Colors.green;
    if (ratio < 0.66) return Colors.amber.shade700;
    return Colors.red;
  }

  /// Shows the emergency escalation dialog when the user has been in critical
  /// risk, past the exposure limit, at the same coordinates for over
  /// [_escalationThresholdSeconds] seconds of exposure time.
  void _showEmergencyEscalationDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.red.shade900.withValues(alpha: 0.55),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: _EscalationDialog(
            formattedExposure: _formattedExposure,
            thresholdMinutes: _escalationThresholdSeconds ~/ 60,
            // Called when the user taps "Call Emergency Services"
            onCallEmergency: () {
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                  content: Text(
                    '🚨 Calling Emergency Services...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
            // Called when the user taps "Navigate to Nearest Shade"
            onNavigateToShade: () {
              Navigator.of(dialogContext).pop();
              if (_currentLocation != null && !_isInShadedArea) {
                LatLng? nearestPoint;
                double minDistance = double.infinity;
                final dist = const Distance();
                for (final zone in _activeZones.where(
                  (z) => z.type == ZoneType.shaded,
                )) {
                  for (final point in zone.points) {
                    final d = dist.distance(_currentLocation!, point);
                    if (d < minDistance) {
                      minDistance = d;
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
                }
              }
            },
            // Called when the user dismisses manually
            onDismiss: () => Navigator.of(dialogContext).pop(),
            // Called automatically when the 3-minute countdown elapses with
            // no interaction — dialog is already popped by the widget itself
            onAutoDispatch: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.deepOrange.shade800,
                    duration: const Duration(seconds: 10),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    content: const Row(
                      children: [
                        Icon(
                          Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '🚑 A nearby emergency worker has been notified and is on the way to your location.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
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
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.heatStressZoneWarning,
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
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

  /// Applies a single turbo step: enables debug mode (if not already on) and
  /// adds +5 minutes of simulated exposure. Exposed as a static callback so
  /// the Settings screen can trigger it without direct widget access.
  Future<void> _applyTurboStep() async {
    if (!mounted) return;
    setState(() {
      _debugMode = true;
      _exposureSeconds += 300;
      final risk = _calculateRiskRatio();
      if (_currentTempValue != null) {
        _maxTempDuringExposure = _maxTempDuringExposure == null
            ? _currentTempValue
            : math.max(_maxTempDuringExposure!, _currentTempValue!);
      }
      _maxRiskDuringExposure = math.max(_maxRiskDuringExposure, risk);
      if (_exposureSeconds > _safeExposureSeconds || risk >= 0.8) {
        _showHeatWarning = true;
      }
    });
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
    _timeProvider?.removeListener(_onTimeChanged);
    ServerConnectionNotifier.setRefreshAction(null);
    ServerConnectionNotifier.setTurboAction(null);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.monitorTitle),
            StreamBuilder(
              stream: Stream.periodic(const Duration(seconds: 1)),
              builder: (context, _) {
                return Text(
                  DateFormat('hh:mm a').format(Provider.of<TimeProvider>(context).now),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70,
                  ),
                );
              },
            ),
          ],
        ),
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
                    _isInAlharam
                        ? AppLocalizations.of(context)!.insideAlharam
                        : AppLocalizations.of(context)!.outsideAlharam,
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
              // Water points marker layer
              MarkerLayer(
                markers: _waterPoints
                    .map(
                      (point) => Marker(
                        point: point,
                        width: 30,
                        height: 30,
                        child: const Icon(
                          Icons.water_drop,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                    )
                    .toList(),
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
    final l10n = AppLocalizations.of(context)!;
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
              children: [
                Text(
                  l10n.criticalHeatRisk,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.seekShadeImmediately,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
              Text(
                AppLocalizations.of(context)!.statusDashboard,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_currentLocation != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isNightTime
                        ? Colors.indigo.shade100
                        : (_isInShadedArea
                            ? Colors.green.shade100
                            : Colors.red.shade100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isNightTime
                            ? Icons.nights_stay
                            : (_isInShadedArea
                                ? Icons.check_circle
                                : Icons.warning_amber_rounded),
                        color: _isNightTime
                            ? Colors.indigo.shade800
                            : (_isInShadedArea
                                ? Colors.green.shade800
                                : Colors.red.shade800),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isNightTime
                            ? AppLocalizations.of(context)!.nighttime
                            : (_isInShadedArea
                                ? AppLocalizations.of(context)!.shaded
                                : AppLocalizations.of(context)!.unshaded),
                        style: TextStyle(
                          color: _isNightTime
                              ? Colors.indigo.shade800
                              : (_isInShadedArea
                                  ? Colors.green.shade800
                                  : Colors.red.shade800),
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
                  label: AppLocalizations.of(context)!.currentTemp,
                  value: _currentTemp,
                  valueColor: Colors.red.shade800,
                ),
                _buildMetricItem(
                  context,
                  icon: Icons.timer_outlined,
                  iconColor: Colors.blueGrey,
                  label: AppLocalizations.of(context)!.sunExposure,
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
                        final l10n = AppLocalizations.of(context)!;
                        if (_currentLocation == null) return;
                        if (_isInShadedArea) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.alreadyInShade),
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
                            SnackBar(
                              content: Text(l10n.routingToShade),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.directions_walk, size: 24),
                      label: Text(
                        AppLocalizations.of(context)!.nearestSafeZone,
                        style: const TextStyle(
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
                        final l10n = AppLocalizations.of(context)!;
                        showDialog(
                          context: context,
                          builder: (BuildContext ctx) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              icon: const Icon(
                                Icons.emergency,
                                color: Colors.red,
                                size: 48,
                              ),
                              title: Text(
                                l10n.emergencySos,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: Text(
                                l10n.areYouSureEmergency,
                                textAlign: TextAlign.center,
                              ),
                              actionsAlignment: MainAxisAlignment.center,
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: Text(
                                    l10n.iUnderstandDismiss,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text(l10n.callingEmergency),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(l10n.callNow),
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
    final String riskText = _getRiskLevelText(riskRatio, context);
    final Color riskColor = _getRiskColor(riskRatio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.riskLevelLabel,
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
        // Dynamic bar: fill width is driven by riskRatio
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              // Background track (green → amber → red gradient)
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    colors: [Colors.green, Colors.amber, Colors.deepOrange],
                  ),
                ),
              ),
              // Unfilled portion covers the right side in grey
              Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 1.0 - _calculateRiskRatio(),
                  child: Container(
                    height: 12,
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
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

// ---------------------------------------------------------------------------
// Emergency Escalation Dialog — StatefulWidget with built-in countdown timer
// ---------------------------------------------------------------------------

class _EscalationDialog extends StatefulWidget {
  final String formattedExposure;
  final int thresholdMinutes;
  final VoidCallback onCallEmergency;
  final VoidCallback onNavigateToShade;
  final VoidCallback onDismiss;
  /// Fired automatically when the 3-minute no-interaction window expires.
  /// The dialog pops itself first, then calls this.
  final VoidCallback onAutoDispatch;

  const _EscalationDialog({
    required this.formattedExposure,
    required this.thresholdMinutes,
    required this.onCallEmergency,
    required this.onNavigateToShade,
    required this.onDismiss,
    required this.onAutoDispatch,
  });

  @override
  State<_EscalationDialog> createState() => _EscalationDialogState();
}

class _EscalationDialogState extends State<_EscalationDialog> {
  /// How long (seconds) before auto-dispatching if the user ignores the dialog.
  static const int _autoDispatchSeconds = 3 * 60;

  late int _secondsLeft;
  Timer? _countdownTimer;
  bool _dispatched = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _autoDispatchSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        timer.cancel();
        _autoDispatch();
      }
    });
  }

  void _autoDispatch() {
    if (_dispatched || !mounted) return;
    _dispatched = true;
    _countdownTimer?.cancel();
    // Pop the dialog first, then fire the parent callback
    Navigator.of(context).pop();
    widget.onAutoDispatch();
  }

  /// Cancels the auto-dispatch before the user's chosen action closes the dialog.
  void _cancelAndRun(VoidCallback action) {
    _dispatched = true;
    _countdownTimer?.cancel();
    action();
  }

  String get _formattedCountdown {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Countdown colour: green → amber → red as time runs out
    final double fraction = _secondsLeft / _autoDispatchSeconds;
    final Color countdownColor = fraction > 0.5
        ? Colors.greenAccent.shade400
        : fraction > 0.25
            ? Colors.amber.shade300
            : Colors.red.shade300;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.red.shade900, Colors.red.shade800],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.shade100, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.45),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emergency, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.emergencyEscalation,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // --- Auto-dispatch countdown ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  AppLocalizations.of(context)!.emergencyWorkerDispatched,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formattedCountdown,
                  style: TextStyle(
                    color: countdownColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.ifNoActionTaken,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Description
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${AppLocalizations.of(context)!.criticalRiskMessage} '
              '${widget.thresholdMinutes} '
              '${AppLocalizations.of(context)!.criticalRiskForMinutes}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${AppLocalizations.of(context)!.totalExposureLabel} ${widget.formattedExposure}',
            style: TextStyle(
              color: Colors.red.shade100,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),

          // Primary: Call now
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.call, size: 22),
              label: Text(
                AppLocalizations.of(context)!.callEmergency,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
              onPressed: () => _cancelAndRun(widget.onCallEmergency),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary: Navigate to shade
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.directions_walk, size: 20),
              label: Text(
                AppLocalizations.of(context)!.navigateToShade,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => _cancelAndRun(widget.onNavigateToShade),
            ),
          ),
          const SizedBox(height: 8),

          // Dismiss
          TextButton(
            onPressed: () => _cancelAndRun(widget.onDismiss),
            child: Text(
              AppLocalizations.of(context)!.iUnderstandDismiss,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

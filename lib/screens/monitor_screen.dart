

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:heatshield/l10n/app_localizations.dart';
import 'package:latlong2/latlong.dart' hide Path;
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
import 'package:flutter_compass/flutter_compass.dart';

/// The three possible safety states for the user's current position.
/// - shaded: inside a shaded zone at ground level (safe)
/// - exposedRoof: above a shaded building (on the roof — exposed)
/// - unshaded: outside all shade zones (exposed at ground level)
enum SafetyStatus { shaded, exposedRoof, unshaded }

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final MapController _mapController =
      MapController(); // Controls the FlutterMap camera (pan, zoom)
  final GeofenceService _geofenceService =
      GeofenceService(); // Triggers snackbar alerts when entering heat zones
  final ZoneDbService _zoneDbService =
      ZoneDbService(); // Reads shaded/unshaded zones from local SQLite DB

  // --- State Variables ---

  // GPS & Map
  LatLng? _currentLocation =
      _initialPosition; // Pre-set so the center FAB is always visible
  StreamSubscription<Position>?
  _positionStreamSubscription; // Active GPS stream listener
  bool _isFollowingLocation =
      true; // Whether the map camera auto-follows the user
  List<LatLng> _routePoints =
      []; // Points for the blue route line drawn on the map

  // Safety status
  SafetyStatus _safetyStatus =
      SafetyStatus.unshaded; // Current shade/exposure state
  bool get _isInShadedArea =>
      _safetyStatus == SafetyStatus.shaded; // Convenience getter

  // Altitude (used to detect rooftop exposure)
  double?
  _groundAltitude; // First GPS altitude reading — used as the ground reference
  double? _currentAltitude; // Latest GPS altitude (with mock offset applied)
  double _mockAltitudeOffset =
      0.0; // Dev tool: simulates being at a higher elevation

  // Weather
  String _currentTemp = '--°C'; // Displayed temperature string
  int? _currentTempValue; // Numeric temperature used in risk calculations

  // Background timers
  Timer? _weatherTimer; // Fetches weather every 15 minutes
  Timer?
  _thresholdTimer; // Refreshes adaptive safe-exposure limit every 1 minute
  Timer? _exposureTimer; // Ticks every second while user is exposed to the sun
  Timer? _zoneRefreshTimer; // Re-applies time-based zone filters every 1 minute
  Timer?
  _watchSyncTimer; // Syncs heat status to the companion watch every second
  bool _isRefreshingServer =
      false; // Guard flag to prevent overlapping server refreshes

  // Compass tracking
  double _heading = 0.0;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // --- Emergency Escalation Tracking ---
  int?
  _criticalRiskStartExposureSeconds; // Snapshot of _exposureSeconds when critical risk first began
  LatLng?
  _criticalRiskStartLocation; // Location snapshot when critical risk first began
  bool _emergencyEscalationTriggered =
      false; // Prevents the dialog from firing more than once per incident

  // Fires after this many seconds of continuous critical risk without movement
  static const int _escalationThresholdSeconds = 10 * 60; // 10 minutes

  // User must move more than this distance (in metres) to reset the escalation clock
  static const double _movementThresholdMetres = 5.0;


  StreamSubscription<void>?
  _zoneUpdatesSubscription; // Listens to ZoneDbService DB change events

  // Exposure tracking
  int _exposureSeconds =
      0; // Running total of seconds in the sun (resets when shaded)
  int?
  _maxTempDuringExposure; // Peak temperature recorded during this exposure session
  double _maxRiskDuringExposure =
      0.0; // Peak risk ratio recorded during this exposure session

  // Zone data
  bool _zonesReady = false; // True once zones have been loaded from the DB
  int _safeExposureSeconds =
      15 * 60; // Adaptive limit from backend; defaults to 15 min
  List<ZonePolygon> _zones = []; // All zones loaded from the local DB
  List<ZonePolygon> _activeZones =
      []; // Zones currently active based on time of day
  List<Polygon> _polygons =
      []; // Flutter map polygon shapes rendered on the map

  static const int _adaptiveUserId =
      0; // User ID sent to backend for personalized thresholds

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

    // Register callbacks so Settings screen can trigger actions on this screen
    // without holding a direct reference to it
    ServerConnectionNotifier.setRefreshAction(_refreshServerConnection);
    ServerConnectionNotifier.setTurboAction(_applyTurboStep);
    ServerConnectionNotifier.setAltitudeAction((offset) {
      if (!mounted) return;
      setState(() {
        _mockAltitudeOffset =
            offset; // Apply simulated altitude offset from dev tools
        _recalculateAltitudeSafeZone(); // Recompute polygon coloring for the new altitude
      });
    });

    // Reload zones whenever the local DB is updated (e.g. after a server sync)
    _zoneUpdatesSubscription = ZoneDbService.updates.listen((_) {
      _loadZones();
    });

    // Re-apply time-based zone filters every minute (zones activate/deactivate by time of day)
    _zoneRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _applyActiveZones(),
    );

    // Push live heat status to the companion watch every second
    _watchSyncTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncHeatStatusToWatch(),
    );

    _loadZones(); // Initial zone load from local DB
    _requestLocationPermission(); // Ask for GPS permission and start tracking
    _fetchWeather(); // Fetch current temperature immediately
    _refreshAdaptiveThreshold(); // Fetch personalized safe-exposure limit immediately

    // Refresh the adaptive threshold every minute (temp or shade status may change)
    _thresholdTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshAdaptiveThreshold(),
    );

    // Re-fetch weather from the backend every 15 minutes
    _weatherTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _fetchWeather(),
    );

    // Subscribe to device compass events to rotate the direction cone on the map
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() {
          _heading = event.heading ?? 0.0;
        });
      }
    });
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

  /// Loads heat zones from the local DB.
  /// Seeds default data if the DB is empty, then syncs from the backend server.
  Future<void> _loadZones() async {
    await _zoneDbService
        .ensureSeedData(); // Insert default zones if the DB is empty
    await _zoneDbService.syncFromBackend(); // Pull latest zones from the server
    final zones = await _zoneDbService.getZones();

    if (!mounted) return;

    setState(() {
      _zones = zones;
      _zonesReady = true; // Mark zones as ready so safety checks can run
    });

    _applyActiveZones(); // Immediately filter to only time-appropriate zones
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

  /// Filters all loaded zones to only those active at the current time,
  /// builds map polygon shapes, and updates the geofencing heat zone list.
  void _applyActiveZones() {
    if (!mounted) return;

    final now = Provider.of<TimeProvider>(context, listen: false).now;

    // Calculate current simulated altitude for filtering
    final currentAlt = (_groundAltitude != null && _currentAltitude != null)
        ? (_groundAltitude! + _mockAltitudeOffset)
        : null;

    // Keep only zones whose active time window includes the current time
    final activeZones = _zones
        .where((zone) => zone.isActiveAt(now))
        .toList(growable: false);

    // Convert each active zone to a map polygon.
    // Shaded zones where the user is above the building height are rendered orange (roof exposure)
    final activePolygons = activeZones
        .map((zone) {
          if (zone.type == ZoneType.shaded &&
              currentAlt != null &&
              _groundAltitude != null) {
            final relativeHeight = currentAlt - _groundAltitude!;
            if (relativeHeight >= zone.buildingHeight) {
              // User is on or above the rooftop — shade is no longer effective
              return Polygon(
                points: zone.points,
                // ignore: deprecated_member_use
                color: Colors.orange.withOpacity(0.3),
                borderColor: Colors.orange,
                borderStrokeWidth: 2,
              );
            }
          }
          return zone
              .toPolygon(); // Normal shaded (green) or unshaded (red) polygon
        })
        .toList(growable: false);

    setState(() {
      _activeZones = activeZones;
      _polygons = activePolygons;
    });

    // Feed only unshaded zone centroids to the geofence service as heat alert triggers
    _geofenceService.setHeatZones(
      activeZones
          .where((zone) => zone.type == ZoneType.unshaded)
          .map((zone) => zone.centroid)
          .toList(),
    );

    _checkInitialLocation(); // Re-evaluate safety status with the new active zones
  }

  /// Fetches real temperature from the backend (with zone heat-delta applied server-side).
  /// Also refreshes the daylight window and adaptive exposure threshold.
  Future<void> _fetchWeather() async {
    try {
      final loc = _currentLocation ?? _initialPosition;
      await _refreshDaylightWindow(loc); // Update sunrise/sunset window first
      final weather = await BackendApiService.fetchEffectiveWeather(
        location: loc,
      );
      if (!mounted) return;

      setState(() {
        _currentTempValue = weather.effectiveTempC.round();
        _currentTemp = '$_currentTempValue°C';
      });
      await _refreshAdaptiveThreshold(); // Recalculate safe exposure limit for the new temp
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
  }

  /// Asks the backend for a personalized safe exposure limit based on
  /// the current user, temperature, and whether they are in shade.
  /// The backend uses past incident data to adapt the threshold over time.
  Future<void> _refreshAdaptiveThreshold() async {
    if (_currentTempValue == null) {
      return; // Can't calculate without a temperature reading
    }

    try {
      final threshold = await BackendApiService.fetchExposureThreshold(
        userId: _adaptiveUserId,
        temp: _currentTempValue!.toDouble(),
        shaded: _isInShadedArea,
      );
      if (!mounted) return;

      setState(() {
        _safeExposureSeconds =
            threshold.safeExposureSeconds; // Update dynamic limit
      });
    } catch (e) {
      debugPrint('Error fetching adaptive threshold: $e');
    }
  }

  /// Returns true if the current time falls outside the backend-provided daylight window.
  /// When true, all heat exposure features are disabled and the UI shows "Nighttime".
  bool get _isNightTime {
    final nowUtc = Provider.of<TimeProvider>(
      context,
      listen: false,
    ).now.toUtc();
    final nowMinute = nowUtc.hour * 60 + nowUtc.minute;
    return !ZonePolygon.isMinuteInWindow(
      nowMinute,
      ZonePolygon.globalDayStartMinute,
      ZonePolygon.globalDayEndMinute,
    );
  }

  void _checkInitialLocation() {
    if (_currentLocation != null && _zonesReady) {
      SafetyStatus status = _getSafetyStatusForPoint(_currentLocation!);
      _safetyStatus = status;
      _isInAlharam = _isPointInPolygon(_currentLocation!, _alharamZonePoints);
      _updateExposureTimer(_isInShadedArea);
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
              final bool hasNotMoved =
                  _criticalRiskStartLocation == null ||
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

  /// Calculates a continuous heat risk ratio from 0.0 (safe) to 1.0 (critical).
  ///
  /// Temperature determines how fast the risk meter rises:
  ///   > 35°C  → critical at 25 min
  ///   30–35°C → critical at 30 min
  ///   25–30°C → critical at 35 min
  ///   ≤ 25°C  → critical at 40 min
  ///
  /// Math: expRisk = (seconds / safeLimit).clamp(0, 0.8)
  /// Critical (0.66) is hit when seconds = 0.825 × safeLimit
  /// → safeLimit = targetCriticalSeconds / 0.825
  double _calculateRiskRatio() {
    if (_isNightTime) return 0.0; // No risk at night — heat monitoring is disabled

    final int temp = _currentTempValue ?? 30; // Default to 30°C if not yet fetched

    // Temperature-tiered safe limit.
    // Calibrated so expRisk (capped at 0.8) crosses 0.66 (critical) at the target time.
    final int tempBasedLimit;
    if (temp > 35) {
      tempBasedLimit = 1818; // > 35°C  → critical at 25 min
    } else if (temp > 30) {
      tempBasedLimit = 2182; // 30–35°C → critical at 30 min
    } else if (temp > 25) {
      tempBasedLimit = 2545; // 25–30°C → critical at 35 min
    } else {
      tempBasedLimit = 2909; // ≤ 25°C  → critical at 40 min
    }

    // Primary driver: exposure ratio capped at 0.8
    final double expRisk = (_exposureSeconds / tempBasedLimit).clamp(0.0, 0.8);

    // Minor time-of-day bonus: peaks at solar noon (+0.02 max)
    // Small enough that it doesn't meaningfully shift the temperature thresholds above
    final now = Provider.of<TimeProvider>(context, listen: false).now;
    final minuteOfDay = now.hour * 60 + now.minute;
    double timeBonus = 0.0;
    if (minuteOfDay >= 360 && minuteOfDay <= 1080) {
      final distanceFromNoon = (minuteOfDay - 720).abs() / 360.0;
      timeBonus = (1.0 - distanceFromNoon).clamp(0.0, 1.0) * 0.02;
    }

    return (expRisk + timeBonus).clamp(0.0, 1.0);
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
              // If the user is on a rooftop, tell them to go downstairs
              // instead of routing them to the zone they're already above.
              if (_safetyStatus == SafetyStatus.exposedRoof) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.orange.shade800,
                    duration: const Duration(seconds: 5),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    content: Row(
                      children: [
                        const Icon(Icons.stairs, color: Colors.white, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.goDownstairs,
                            style: const TextStyle(
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
                return;
              }
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
            onAutoDispatch: () async {
              if (mounted) {
                if (_currentLocation != null) {
                  try {
                    await BackendApiService.createEMReport(
                      userId: _adaptiveUserId,
                      locationLat: _currentLocation!.latitude,
                      locationLng: _currentLocation!.longitude,
                    );
                  } catch (e) {
                    debugPrint('Failed to create EM Report: $e');
                  }
                }

                if (!mounted) return;
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

  /// Listens to the device GPS stream and updates the user's position,
  /// altitude, safety status, Alharam boundary, and route line on every fix.
  void _startLocationTracking() {
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter:
                5, // Only emit updates when user moves at least 5 metres
          ),
        ).listen((Position position) {
          if (!mounted) return;
          final newLoc = LatLng(position.latitude, position.longitude);

          _currentAltitude = position.altitude + _mockAltitudeOffset;
          _groundAltitude ??= position
              .altitude; // Capture the first fix as the ground reference

          setState(() {
            _currentLocation = newLoc;
          });

          // Recalculate polygon colors if altitude crossed a building-height threshold
          _applyActiveZones();

          SafetyStatus status = _getSafetyStatusForPoint(newLoc);

          setState(() {
            _currentLocation = newLoc;
            _safetyStatus = status;
            _isInAlharam = _isPointInPolygon(newLoc, _alharamZonePoints);
            _updateExposureTimer(_isInShadedArea);
            if (_isInShadedArea) {
              _routePoints.clear(); // User reached shade — clear the route
            } else if (_routePoints.isNotEmpty) {
              final distanceToDestination = const Distance().distance(
                newLoc,
                _routePoints.last,
              );
              if (distanceToDestination < 10.0) {
                _routePoints
                    .clear(); // Close enough to destination — clear route
              } else {
                _routePoints[0] =
                    newLoc; // Update the route start to the current position
              }
            }
          });
        });
  }

  void _recalculateAltitudeSafeZone() {
    _groundAltitude ??= 0.0;
    _currentAltitude = _groundAltitude! + _mockAltitudeOffset;
    _applyActiveZones();
  }

  /// Determines the user's safety status for a given coordinate.
  /// Checks each active shaded zone using point-in-polygon.
  /// If inside a zone but altitude >= building height → exposedRoof.
  /// If inside a zone at ground level → shaded.
  /// Otherwise → unshaded.
  SafetyStatus _getSafetyStatusForPoint(LatLng point) {
    final currentAlt = (_groundAltitude != null && _currentAltitude != null)
        ? (_groundAltitude! + _mockAltitudeOffset)
        : null;

    bool onRoof = false;
    for (final zone in _activeZones.where((z) => z.type == ZoneType.shaded)) {
      if (_isPointInPolygon(point, zone.points)) {
        if (currentAlt != null && _groundAltitude != null) {
          final relativeHeight = currentAlt - _groundAltitude!;
          if (relativeHeight >= zone.buildingHeight) {
            onRoof = true;
            continue; // Keep checking other shaded zones, maybe one is taller
          }
        }
        return SafetyStatus.shaded; // Safe
      }
    }
    return onRoof ? SafetyStatus.exposedRoof : SafetyStatus.unshaded;
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

  /// Adds +5 minutes of simulated exposure and enables debug mode.
  /// Triggered from the Settings screen via the Turbo Mode developer tool.
  Future<void> _applyTurboStep() async {
    if (!mounted) return;
    setState(() {
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
    // Cancel all streams and timers to prevent memory leaks
    _positionStreamSubscription?.cancel();
    _zoneUpdatesSubscription?.cancel();
    _zoneRefreshTimer?.cancel();
    _geofenceService.dispose();
    _watchSyncTimer?.cancel();
    _weatherTimer?.cancel();
    _thresholdTimer?.cancel();
    _exposureTimer?.cancel();
    _compassSubscription?.cancel();
    _timeProvider?.removeListener(_onTimeChanged);
    // Clear Settings callbacks so they don’t point to a disposed widget
    ServerConnectionNotifier.setRefreshAction(null);
    ServerConnectionNotifier.setTurboAction(null);
    ServerConnectionNotifier.setAltitudeAction(null);
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
                  DateFormat(
                    'hh:mm a',
                  ).format(Provider.of<TimeProvider>(context).now),
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
                SafetyStatus status = _getSafetyStatusForPoint(point);

                setState(() {
                  _currentLocation = point;
                  _safetyStatus = status;
                  _isInAlharam = _isPointInPolygon(point, _alharamZonePoints);
                  _updateExposureTimer(_isInShadedArea);
                  _isFollowingLocation = false;
                  if (_isInShadedArea) {
                    _routePoints.clear();
                  } else if (_routePoints.isNotEmpty) {
                    final distanceToDestination = const Distance().distance(
                      point,
                      _routePoints.last,
                    );
                    if (distanceToDestination < 10.0) {
                      _routePoints.clear();
                    } else {
                      _routePoints[0] = point;
                    }
                  }
                });

                // Print the latitude and longitude when the user taps the map
                final lat = point.latitude.toStringAsFixed(5);
                final lng = point.longitude.toStringAsFixed(5);
                debugPrint('Tapped: $lat, $lng');
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
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Direction vision cone
                          Transform.rotate(
                            angle: _heading * (math.pi / 180),
                            child: CustomPaint(
                              size: const Size(80, 80),
                              painter: _VisionConePainter(),
                            ),
                          ),
                          // User dot
                          const Stack(
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
                        : (_safetyStatus == SafetyStatus.shaded
                              ? Colors.green.shade100
                              : (_safetyStatus == SafetyStatus.exposedRoof
                                    ? Colors.orange.shade100
                                    : Colors.red.shade100)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isNightTime
                            ? Icons.nights_stay
                            : (_safetyStatus == SafetyStatus.shaded
                                  ? Icons.check_circle
                                  : (_safetyStatus == SafetyStatus.exposedRoof
                                        ? Icons.vertical_align_top
                                        : Icons.warning_amber_rounded)),
                        color: _isNightTime
                            ? Colors.indigo.shade800
                            : (_safetyStatus == SafetyStatus.shaded
                                  ? Colors.green.shade800
                                  : (_safetyStatus == SafetyStatus.exposedRoof
                                        ? Colors.orange.shade800
                                        : Colors.red.shade800)),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isNightTime
                            ? AppLocalizations.of(context)!.nighttime
                            : (_safetyStatus == SafetyStatus.shaded
                                  ? AppLocalizations.of(context)!.shaded
                                  : (_safetyStatus == SafetyStatus.exposedRoof
                                        ? 'Exposed(roof)'
                                        : AppLocalizations.of(
                                            context,
                                          )!.unshaded)),
                        style: TextStyle(
                          color: _isNightTime
                              ? Colors.indigo.shade800
                              : (_safetyStatus == SafetyStatus.shaded
                                    ? Colors.green.shade800
                                    : (_safetyStatus == SafetyStatus.exposedRoof
                                          ? Colors.orange.shade800
                                          : Colors.red.shade800)),
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
                        // On the rooftop of a shaded zone — tell user to go downstairs
                        if (_safetyStatus == SafetyStatus.exposedRoof) {
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              Future.delayed(const Duration(seconds: 3), () {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              });
                              return AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.stairs,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(l10n.nearestSafeZone),
                                  ],
                                ),
                                content: Text(l10n.goDownstairs),
                              );
                            },
                          );
                          return;
                        }
                        if (_isInShadedArea) {
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              Future.delayed(const Duration(seconds: 1), () {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              });
                              return AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.info,
                                      color: Colors.teal.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(l10n.nearestSafeZone),
                                  ],
                                ),
                                content: Text(l10n.alreadyInShade),
                              );
                            },
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
                            _isFollowingLocation = true;
                          });

                          _mapController.move(_currentLocation!, 17.5);

                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              Future.delayed(const Duration(seconds: 1), () {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              });
                              return AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.directions_walk,
                                      color: Colors.teal.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(l10n.nearestSafeZone),
                                  ],
                                ),
                                content: Text(l10n.routingToShade),
                              );
                            },
                          );
                        }
                      },
                      icon: const Icon(Icons.directions_walk, size: 24),
                      label: Text(
                        AppLocalizations.of(context)!.nearestSafeZone,
                        style: const TextStyle(
                          fontSize: 12,
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
                // --- Nearest Water Point button ---
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final l10n = AppLocalizations.of(context)!;
                        if (_currentLocation == null) return;

                        LatLng? nearestWater;
                        double minWaterDist = double.infinity;
                        final dist = const Distance();

                        for (final wp in _waterPoints) {
                          final d = dist.distance(_currentLocation!, wp);
                          if (d < minWaterDist) {
                            minWaterDist = d;
                            nearestWater = wp;
                          }
                        }

                        if (nearestWater != null) {
                          setState(() {
                            _routePoints = [_currentLocation!, nearestWater!];
                            _isFollowingLocation = true;
                          });
                          _mapController.move(_currentLocation!, 17.5);
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              Future.delayed(const Duration(seconds: 1), () {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              });
                              return AlertDialog(
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.water_drop,
                                      color: Colors.blue.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(l10n.nearestWaterPoint),
                                  ],
                                ),
                                content: Text(l10n.routingToWater),
                              );
                            },
                          );
                        } else {
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              Future.delayed(const Duration(seconds: 1), () {
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              });
                              return AlertDialog(
                                title: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(l10n.nearestWaterPoint),
                                  ],
                                ),
                                content: Text(l10n.noWaterPointFound),
                              );
                            },
                          );
                        }
                      },
                      icon: const Icon(Icons.water_drop, size: 22),
                      label: Text(
                        AppLocalizations.of(context)!.nearestWaterPoint,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
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
                    child: ElevatedButton(
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emergency, size: 24),
                          SizedBox(height: 2),
                          Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
  static const int _autoDispatchSeconds = 1 * 60;

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

/// A simple CustomPainter that draws a translucent blue direction cone
/// on the user's map marker. The cone always points "up" (north) in canvas
/// space — it is rotated externally by Transform.rotate using the compass heading.
class _VisionConePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    path.moveTo(center.dx, center.dy);
    // Point pointing forward (up, to y=0)
    path.lineTo(center.dx - 25, 0);
    // Slight curve at the far edge
    path.quadraticBezierTo(center.dx, -10, center.dx + 25, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

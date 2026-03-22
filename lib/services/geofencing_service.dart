import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

/// A service class that monitors the device's location in the background
/// and triggers alerts when the user approaches defined high-risk heat zones.
class GeofenceService {
  List<LatLng> _heatZones = [];

  final double alertDistance = 100.0; // Trigger alert if < 100m
  StreamSubscription<Position>? _positionStreamSubscription;

  VoidCallback? _onAlert;

  void setHeatZones(List<LatLng> zones) {
    _heatZones = List<LatLng>.from(zones);
  }

  /// Requests location permissions, checks if location services are enabled,
  /// and starts continuous background monitoring if everything is approved.
  Future<void> initialize({VoidCallback? onAlert}) async {
    _onAlert = onAlert;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Handle location services are disabled.
      return;
    }

    var status = await Permission.locationAlways.status;
    if (status.isDenied) {
      status = await Permission.locationAlways.request();
    }

    if (status.isGranted) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _checkGeofences(position);
          },
        );
  }

  /// Compares the user's current [position] against all active dangerous (unshaded)
  /// heat zones. Triggers the alert callback if the user is within [alertDistance].
  void _checkGeofences(Position position) {
    for (var zone in _heatZones) {
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zone.latitude,
        zone.longitude,
      );

      if (distanceInMeters < alertDistance) {
        if (_onAlert != null) {
          _onAlert!();
        }
        break; // Only trigger once if close to multiple
      }
    }
  }

  void dispose() {
    _positionStreamSubscription?.cancel();
  }
}

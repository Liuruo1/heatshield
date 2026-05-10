import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  group('GeofenceService Logic Tests', () {
    const double alertThreshold = 100.0; //

    test('Should identify point within alert range', () {
      // Mock coordinates for the Holy Mosque area
      const zoneLat = 21.4225;
      const zoneLng = 39.8262;

      // User is ~50 meters away
      const userLat = 21.4228;
      const userLng = 39.8262;

      double distance = Geolocator.distanceBetween(
        userLat,
        userLng,
        zoneLat,
        zoneLng,
      );

      expect(distance < alertThreshold, isTrue); //
    });

    test('Should ignore points outside 100m range', () {
      const zoneLat = 21.4225;
      const zoneLng = 39.8262;

      // User is far away
      const userLat = 21.4500;
      const userLng = 39.8500;

      double distance = Geolocator.distanceBetween(
        userLat,
        userLng,
        zoneLat,
        zoneLng,
      );

      expect(distance > alertThreshold, isTrue); //
    });
  });
}

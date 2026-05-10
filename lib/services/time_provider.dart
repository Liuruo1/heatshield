import 'package:flutter/material.dart';

/// A simple state management service to mock the current time for testing.
class TimeProvider extends ChangeNotifier {
  DateTime? _mockTime;
  int _simulatedExposureMinutes = 0;

  /// Returns the mocked time if set, otherwise returns the actual system time.
  DateTime get now => _mockTime ?? DateTime.now();

  /// The total number of simulated exposure minutes added via Turbo Mode.
  int get simulatedExposureMinutes => _simulatedExposureMinutes;

  /// Adds 5 minutes of simulated heat exposure (Turbo Mode tap).
  void addTurboExposure() {
    _simulatedExposureMinutes += 5;
    notifyListeners();
  }

  /// Resets the simulated exposure counter to zero.
  void resetSimulatedExposure() {
    _simulatedExposureMinutes = 0;
    notifyListeners();
  }

  /// Whether a mock time is currently set.
  bool get isMocking => _mockTime != null;

  /// Sets a static mock time of day.
  void setMockTime(TimeOfDay timeOfDay) {
    final DateTime current = DateTime.now();
    _mockTime = DateTime(
      current.year,
      current.month,
      current.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    notifyListeners();
  }

  /// Clears the mock time, reverting to real system time.
  void clearMockTime() {
    if (_mockTime != null) {
      _mockTime = null;
      notifyListeners();
    }
  }
}

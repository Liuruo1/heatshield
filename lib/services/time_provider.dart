import 'package:flutter/material.dart';

/// A simple state management service to mock the current time for testing.
class TimeProvider extends ChangeNotifier {
  DateTime? _mockTime;

  /// Returns the mocked time if set, otherwise returns the actual system time.
  DateTime get now => _mockTime ?? DateTime.now();

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

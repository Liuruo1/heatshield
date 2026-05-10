import 'package:flutter_test/flutter_test.dart';
import 'package:heatshield/services/time_provider.dart';

void main() {
  test('TimeProvider should correctly increment simulated exposure', () {
    final timeProvider = TimeProvider(); //

    // Initial exposure should be 0
    expect(timeProvider.simulatedExposureMinutes, 0);

    // Simulate "Turbo Mode" tap [cite: 69, 80]
    timeProvider.addTurboExposure();

    expect(timeProvider.simulatedExposureMinutes, 5);
  });
}

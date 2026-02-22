import 'package:flutter_test/flutter_test.dart';

import 'package:heatshield/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HeatShieldApp());
  });
}

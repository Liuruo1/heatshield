import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heatshield/services/watch_companion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.heatshield/watch_companion');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('sends live status to the iOS WatchConnectivity bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return true;
    });

    final sent = await WatchCompanionService.sendHeatStatus(
      temp: null,
      exposure: 75,
      risk: 0.6,
      shaded: false,
      safeExposureSeconds: 900,
    );

    expect(sent, isTrue);
    expect(receivedCall?.method, 'updateWatchStatus');
    final arguments = receivedCall!.arguments as Map<Object?, Object?>;
    expect(arguments, containsPair('temp', null));
    expect(arguments, containsPair('exposure', 75));
    expect(arguments, containsPair('safeExposureSeconds', 900));
    expect(arguments['timestampMs'], isA<int>());
  });

  test('keeps sending status to the existing Android bridge', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    MethodCall? receivedCall;
    messenger.setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return true;
    });

    final sent = await WatchCompanionService.sendHeatStatus(
      temp: 32,
      exposure: 75,
      risk: 0.6,
      shaded: false,
    );

    expect(sent, isTrue);
    expect(receivedCall?.method, 'sendHeatStatusToWatch');
  });

  test('does not call the companion channel on unsupported platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    var called = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return true;
    });

    final sent = await WatchCompanionService.sendHeatStatus(
      temp: 32,
      exposure: 75,
      risk: 0.6,
      shaded: false,
    );

    expect(sent, isFalse);
    expect(called, isFalse);
  });
}

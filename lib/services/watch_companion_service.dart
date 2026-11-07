import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WatchCompanionService {
  WatchCompanionService._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.heatshield/watch_companion',
  );

  static Future<bool> isWatchReachable() async {
    final reachable = await _channel.invokeMethod<bool>('isWatchReachable');
    return reachable ?? false;
  }

  static Future<bool> sendMessage({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    final sent = await _channel.invokeMethod<bool>('sendMessageToWatch', {
      'path': path,
      'payload': jsonEncode(payload),
    });

    return sent ?? false;
  }

  static Future<bool> sendAlertUpdate({
    required String level,
    required String message,
    int? timestampMs,
  }) {
    return sendMessage(
      path: '/heatshield/alert',
      payload: {
        'type': 'alert_update',
        'level': level,
        'message': message,
        'timestampMs': timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static Future<bool> sendMonitorStatus({
    required bool monitoring,
    String? zoneName,
    int? timestampMs,
  }) {
    return sendMessage(
      path: '/heatshield/status',
      payload: {
        'type': 'monitor_status',
        'monitoring': monitoring,
        'zoneName': zoneName,
        'timestampMs': timestampMs ?? DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static Future<bool> sendHeatStatus({
    required int? temp,
    required int exposure,
    required double risk,
    required bool shaded,
    int? safeExposureSeconds,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final method = defaultTargetPlatform == TargetPlatform.iOS
        ? 'updateWatchStatus'
        : 'sendHeatStatusToWatch';
    final arguments = {
      'temp': temp,
      'exposure': exposure,
      'risk': risk,
      'shaded': shaded,
      'safeExposureSeconds': safeExposureSeconds,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      final sent = await _channel.invokeMethod<bool>(method, arguments);
      return sent ?? false;
    } on PlatformException catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'heatshield',
          context: ErrorDescription('while sending heat status to the watch'),
        ),
      );
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'heatshield',
          context: ErrorDescription('while locating the watch companion channel'),
        ),
      );
      return false;
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ServerConnectionNotifier {
  ServerConnectionNotifier._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static bool _isBannerVisible = false;
  static Future<void> Function()? _refreshAction;

  static void setRefreshAction(Future<void> Function()? refreshAction) {
    _refreshAction = refreshAction;
  }

  static void clearNoConnectionError() {
    if (!_isBannerVisible) {
      return;
    }

    scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner();
    _isBannerVisible = false;
  }

  static void showNoConnectionError() {
    if (_isBannerVisible) {
      return;
    }

    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }

    _isBannerVisible = true;
    messenger.showMaterialBanner(
      MaterialBanner(
        content: const Text('No connection to server.'),
        backgroundColor: Colors.red.shade700,
        actions: [
          TextButton(
            onPressed: () async {
              final refreshAction = _refreshAction;
              if (refreshAction == null) {
                return;
              }

              try {
                await refreshAction();
              } catch (_) {
                // Keep the banner visible until a refresh succeeds.
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  static bool isConnectionError(Object error) {
    final message = error.toString().toLowerCase();
    return error is TimeoutException ||
        error is http.ClientException ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('connection timed out') ||
        message.contains('network is unreachable') ||
        message.contains('connection closed');
  }
}

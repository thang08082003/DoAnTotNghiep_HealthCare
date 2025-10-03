import 'dart:io';
import 'package:flutter/services.dart';
import 'local_notifications_service.dart';

class AndroidForegroundService {
  static const _channel = MethodChannel('com.example.healthcare/foreground');
  static bool _listening = false;

  static Future<void> start(String userId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startForegroundService', {'userId': userId});
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (_) {}
  }

  static void ensureTapListener() {
    if (_listening) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTap') {
        final payload = (call.arguments as Map?)?['payload'] as String?;
        LocalNotificationsService.handleNotificationTapFromSystem(payload);
      }
    });
    _listening = true;
  }
}

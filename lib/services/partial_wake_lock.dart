import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PartialWakeLock {
  static const _channel = MethodChannel('cwreader/wake_lock');
  static bool _notificationAsked = false;

  static Future<void> enable() async {
    try {
      await _maybeRequestNotificationPermission();
      await _channel.invokeMethod('enable');
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}
  }

  static Future<void> _maybeRequestNotificationPermission() async {
    if (_notificationAsked) return;
    if (kIsWeb || !Platform.isAndroid) return;
    final status = await Permission.notification.status;
    if (status == PermissionStatus.denied) {
      _notificationAsked = true;
      await Permission.notification.request();
    }
  }
}

import 'package:flutter/services.dart';

class PartialWakeLock {
  static const _channel = MethodChannel('cwreader/wake_lock');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {}
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}
  }
}

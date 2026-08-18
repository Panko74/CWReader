import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class NativeStreamPlayer {
  static const _channel = MethodChannel('cwreader/audio');

  static bool get available => !kIsWeb && Platform.isAndroid;

  Future<bool> init({required int sampleRate, required int channels}) async {
    try {
      await _channel.invokeMethod('init', {
        'sampleRate': sampleRate,
        'channels': channels,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> write(Uint8List bytes) async {
    try {
      await _channel.invokeMethod('write', {'bytes': bytes});
    } catch (_) {}
  }

  Future<void> flush() async {
    try {
      await _channel.invokeMethod('flush');
    } catch (_) {}
  }

  Future<void> reset() async {
    try {
      await _channel.invokeMethod('reset');
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await _channel.invokeMethod('resume');
    } catch (_) {}
  }

  Future<int> playedFrames() async {
    try {
      return (await _channel.invokeMethod('getPlayedFrames') as num?)?.toInt() ??
          0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }
}
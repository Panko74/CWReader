import 'dart:math';
import 'dart:typed_data';
import '../models/player_state.dart';

class AudioGenerator {
  static const int sampleRate = 44100;
  static const int bitsPerSample = 16;
  static const int numChannels = 1;

  final int wpm;
  final int farnsworthMs;
  final double extraWordSpaceMultiplier;
  final int frequency;
  final Waveform waveform;
  final double volume;

  AudioGenerator({
    this.wpm = 20,
    this.farnsworthMs = 0,
    this.extraWordSpaceMultiplier = 1.0,
    this.frequency = 600,
    this.waveform = Waveform.sine,
    this.volume = 1.0,
  });

  factory AudioGenerator.fromSettings(AppSettings settings) {
    return AudioGenerator(
      wpm: settings.wpm,
      farnsworthMs: settings.farnsworth,
      extraWordSpaceMultiplier: settings.extraWordSpace,
      frequency: settings.frequency,
      waveform: settings.waveform,
      volume: settings.volume,
    );
  }

  double get unitMs => 1200.0 / wpm;

  int get dotSamples => (unitMs * sampleRate / 1000).round();
  int get dashSamples => (3 * unitMs * sampleRate / 1000).round();
  int get intraCharGapSamples =>
      (unitMs * sampleRate / 1000).round();
  int get interCharGapSamples =>
      ((3 * unitMs + farnsworthMs) * sampleRate / 1000).round();
  int get wordGapSamples =>
      ((7 * unitMs * extraWordSpaceMultiplier) * sampleRate / 1000).round();

  static List<int> computeTokenSamplePositions(
      List<String> tokens, AudioGenerator gen) {
    final positions = <int>[];
    int pos = 0;
    for (final token in tokens) {
      positions.add(pos);
      if (token == ' ' || token == '/') {
        pos += gen.wordGapSamples;
      } else {
        for (int i = 0; i < token.length; i++) {
          if (i > 0) pos += gen.intraCharGapSamples;
          pos += token[i] == '.' ? gen.dotSamples : gen.dashSamples;
        }
        pos += gen.interCharGapSamples;
      }
    }
    return positions;
  }

  static int findTokenIndex(List<int> positions, int samplePos) {
    if (positions.isEmpty) return 0;
    var idx = 0;
    for (int i = 0; i < positions.length; i++) {
      if (positions[i] <= samplePos) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  double _generateSample(double t) {
    final phase = 2 * pi * frequency * t;
    switch (waveform) {
      case Waveform.sine:
        return sin(phase);
      case Waveform.square:
        return sin(phase) >= 0 ? 1.0 : -1.0;
      case Waveform.triangle:
        return 2.0 *
                (2.0 * (frequency * t - (frequency * t).floor()) - 1.0)
                    .abs() -
            1.0;
      case Waveform.sawtooth:
        return 2.0 * (frequency * t - (frequency * t).floor()) - 1.0;
    }
  }

  Uint8List tokensToWav(List<String> tokens) {
    final pcmBytes = _generatePcm(tokens);
    return _buildWav(pcmBytes);
  }

  Int16List _generatePcm(List<String> tokens) {
    var totalSamples = 0;
    final segments = <_Segment>[];

    for (final token in tokens) {
      if (token == ' ') {
        segments.add(_Segment.silence(wordGapSamples));
        totalSamples += wordGapSamples;
      } else if (token == '/') {
        segments.add(_Segment.silence(wordGapSamples));
        totalSamples += wordGapSamples;
      } else {
        for (int i = 0; i < token.length; i++) {
          if (i > 0) {
            segments.add(_Segment.silence(intraCharGapSamples));
            totalSamples += intraCharGapSamples;
          }
          if (token[i] == '.') {
            segments.add(_Segment.tone(dotSamples));
            totalSamples += dotSamples;
          } else if (token[i] == '-') {
            segments.add(_Segment.tone(dashSamples));
            totalSamples += dashSamples;
          }
        }
        segments.add(_Segment.silence(interCharGapSamples));
        totalSamples += interCharGapSamples;
      }
    }

    final pcm = Int16List(totalSamples);
    var offset = 0;
    for (final seg in segments) {
      if (seg.isTone) {
        for (int i = 0; i < seg.samples; i++) {
          final t = i / sampleRate;
          final value = _generateSample(t);
          pcm[offset + i] =
              (value * volume * 32767).clamp(-32768, 32767).toInt();
        }
      }
      offset += seg.samples;
    }

    return pcm;
  }

  Uint8List _buildWav(Int16List pcm) {
    final dataSize = pcm.length * 2;
    final fileSize = 44 + dataSize;
    final buffer = Uint8List(fileSize);
    final view = ByteData.view(buffer.buffer);

    view.setUint8(0, 0x52);
    view.setUint8(1, 0x49);
    view.setUint8(2, 0x46);
    view.setUint8(3, 0x46);
    view.setUint32(4, fileSize - 8, Endian.little);
    view.setUint8(8, 0x57);
    view.setUint8(9, 0x41);
    view.setUint8(10, 0x56);
    view.setUint8(11, 0x45);

    view.setUint8(12, 0x66);
    view.setUint8(13, 0x6D);
    view.setUint8(14, 0x74);
    view.setUint8(15, 0x20);
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, numChannels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(
        28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little);
    view.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
    view.setUint16(34, bitsPerSample, Endian.little);

    view.setUint8(36, 0x64);
    view.setUint8(37, 0x61);
    view.setUint8(38, 0x74);
    view.setUint8(39, 0x61);
    view.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < pcm.length; i++) {
      view.setInt16(44 + i * 2, pcm[i], Endian.little);
    }

    return buffer;
  }
}

class _Segment {
  final int samples;
  final bool isTone;
  const _Segment.tone(this.samples) : isTone = true;
  const _Segment.silence(this.samples) : isTone = false;
}

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
  final int envelopeSamples;
  final double qsb;
  final double qsbPeriod;
  final double bandNoise;
  final double qrn;
  final FistType fistType;
  final double fistAmount;

  /// Absolute index of the first token in the stream being generated.
  /// Used to keep the timing jitter deterministic between the full-stream
  /// index map and the chunked PCM generation.
  final int seed;

  AudioGenerator({
    this.wpm = 20,
    this.farnsworthMs = 0,
    this.extraWordSpaceMultiplier = 1.0,
    this.frequency = 600,
    this.waveform = Waveform.sine,
    this.volume = 1.0,
    this.envelopeSamples = 0,
    this.qsb = 0.0,
    this.qsbPeriod = 4.0,
    this.bandNoise = 0.0,
    this.qrn = 0.0,
    this.fistType = FistType.off,
    this.fistAmount = 0.5,
    this.seed = 0,
  });

  factory AudioGenerator.fromSettings(AppSettings settings, {int seed = 0}) {
    final envSamples =
        (settings.envelopeMs * sampleRate / 1000).round().clamp(0, 50);
    return AudioGenerator(
      wpm: settings.wpm,
      farnsworthMs: settings.farnsworth,
      extraWordSpaceMultiplier: settings.extraWordSpace,
      frequency: settings.frequency,
      waveform: settings.waveform,
      volume: settings.volume,
      envelopeSamples: envSamples,
      qsb: settings.qsb,
      qsbPeriod: settings.qsbPeriod,
      bandNoise: settings.bandNoise,
      qrn: settings.qrn,
      fistType: settings.fistType,
      fistAmount: settings.fistAmount,
      seed: seed,
    );
  }

  double get unitMs => 1200.0 / wpm;

  int get _baseDot => (unitMs * sampleRate / 1000).round();
  int get _baseDash => (3 * unitMs * sampleRate / 1000).round();
  int get _baseIntra => (unitMs * sampleRate / 1000).round();
  int get _baseInter =>
      ((3 * unitMs + farnsworthMs) * sampleRate / 1000).round();
  int get _baseWord =>
      ((7 * unitMs * extraWordSpaceMultiplier) * sampleRate / 1000).round();

  _FistParams _fistParams() {
    switch (fistType) {
      case FistType.bug:
        return const _FistParams(
            dot: 0.02, dash: 0.5, dashSlow: 0.5, gap: 0.25);
      case FistType.straight:
        return const _FistParams(
            dot: 0.35, dash: 0.35, dashSlow: 0.0, gap: 0.25);
      case FistType.paddle:
        return const _FistParams(
            dot: 0.0, dash: 0.05, dashSlow: 0.0, gap: 0.25);
      case FistType.sideswiper:
        return const _FistParams(
            dot: 0.45, dash: 0.4, dashSlow: 0.08, gap: 0.3);
      case FistType.off:
        return const _FistParams(
            dot: 0, dash: 0, dashSlow: 0, gap: 0);
    }
  }

  /// Deterministic pseudo-random value in [0, 1) derived from an absolute
  /// token index and an element index. This guarantees that the same element
  /// receives the same jitter whether it is processed as part of the full
  /// stream or as part of a smaller chunk.
  static double _hashRand(int absToken, int elem) {
    var h = absToken & 0x7FFFFFFF;
    h = (h * 0x9E3779B9 + (elem + 1) * 0x85EBCA6B) & 0x7FFFFFFF;
    h ^= h >> 13;
    h = (h * 0x5BD1E995) & 0x7FFFFFFF;
    h ^= h >> 15;
    return (h & 0x7FFFFF) / 0x7FFFFF;
  }

  int _jittered(int base, int absToken, int elem, double jitterMax,
      double bias, int minVal, int maxVal) {
    if (fistType == FistType.off || fistAmount <= 0) return base;
    final r = _hashRand(absToken, elem);
    final j = 1.0 + fistAmount * (bias + jitterMax * (r * 2 - 1));
    return (base * j).round().clamp(minVal, maxVal);
  }

  int _dotSamplesAt(int absToken, int elem, _FistParams p) {
    return _jittered(_baseDot, absToken, elem, p.dot, 0, 1, _baseDot * 4);
  }

  int _dashSamplesAt(int absToken, int elem, _FistParams p) {
    return _jittered(
        _baseDash, absToken, elem, p.dash, p.dashSlow, _baseDot, _baseDash * 5);
  }

  int _gapSamplesAt(int base, int absToken, int elem, _FistParams p) {
    return _jittered(base, absToken, elem, p.gap, 0, 0, base * 4);
  }

  _TimingResult _computeTiming(List<String> tokens) {
    final p = _fistParams();
    final segments = <_Segment>[];
    final tokenStarts = <int>[];
    int pos = 0;
    for (int ti = 0; ti < tokens.length; ti++) {
      final token = tokens[ti];
      final absToken = seed + ti;
      tokenStarts.add(pos);
      int elem = 0;
      if (token == ' ' || token == '/') {
        final s = _gapSamplesAt(_baseWord, absToken, elem++, p);
        segments.add(_Segment.silence(s));
        pos += s;
      } else {
        for (int i = 0; i < token.length; i++) {
          if (i > 0) {
            final s = _gapSamplesAt(_baseIntra, absToken, elem++, p);
            segments.add(_Segment.silence(s));
            pos += s;
          }
          if (token[i] == '.') {
            final s = _dotSamplesAt(absToken, elem++, p);
            segments.add(_Segment.tone(s));
            pos += s;
          } else if (token[i] == '-') {
            final s = _dashSamplesAt(absToken, elem++, p);
            segments.add(_Segment.tone(s));
            pos += s;
          }
        }
        final s = _gapSamplesAt(_baseInter, absToken, elem++, p);
        segments.add(_Segment.silence(s));
        pos += s;
      }
    }
    return _TimingResult(segments, tokenStarts, pos);
  }

  static List<int> computeTokenSamplePositions(
      List<String> tokens, AudioGenerator gen) {
    return gen._computeTiming(tokens).tokenStarts;
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

  Int16List tokensToPcm(List<String> tokens) {
    return _generatePcm(tokens);
  }

  int sampleCountFor(List<String> tokens) {
    return _computeTiming(tokens).totalSamples;
  }

  Int16List _generatePcm(List<String> tokens) {
    final timing = _computeTiming(tokens);
    final segments = timing.segments;
    final totalSamples = timing.totalSamples;

    final pcm = Int16List(totalSamples);
    if (totalSamples == 0) return pcm;

    final qsbGain = _buildQsbGain(totalSamples);
    final noise = _buildBandNoise(totalSamples);
    final crackle = _buildQrn(totalSamples);

    var offset = 0;
    for (final seg in segments) {
      final n = seg.samples;
      for (int i = 0; i < n; i++) {
        final idx = offset + i;
        double s = 0.0;
        if (seg.isTone) {
          double env = 1.0;
          if (envelopeSamples > 0 && n > 1) {
            if (i < envelopeSamples) {
              env = i / envelopeSamples;
            } else if (i >= n - envelopeSamples) {
              env = (n - 1 - i) / envelopeSamples;
            }
          }
          final t = i / sampleRate;
          s = _generateSample(t) * env * volume * qsbGain[idx] * 32767;
        }
        if (bandNoise > 0) s += noise[idx] * bandNoise * 32767 * 0.5;
        if (qrn > 0) s += crackle[idx] * qrn * 32767 * 1.0;
        pcm[idx] = s.clamp(-32768, 32767).toInt();
      }
      offset += n;
    }

    return pcm;
  }

  Float64List _buildQsbGain(int totalSamples) {
    final gain = Float64List(totalSamples);
    if (qsb <= 0) {
      for (int i = 0; i < totalSamples; i++) {
        gain[i] = 1.0;
      }
      return gain;
    }
    final rng = _Rng((seed ^ 0x9E3779B9) & 0x7FFFFFFF);
    final maxDb = 30.0 * qsb;
    final p = qsbPeriod.clamp(10.0, 35.0);
    final freqs = [1.0 / p, 1.6 / p, 2.6 / p];
    final phases = [for (var i = 0; i < freqs.length; i++) rng.next() * 2 * pi];
    final amps = [for (var i = 0; i < freqs.length; i++) 0.6 + rng.next() * 0.4];
    final ampSum = amps[0] + amps[1] + amps[2];
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      double env = 0;
      for (int k = 0; k < freqs.length; k++) {
        env += amps[k] * sin(2 * pi * freqs[k] * t + phases[k]);
      }
      env = (env / ampSum).clamp(-1.0, 1.0);
      final depth = 0.5 - 0.5 * env;
      final shaped = pow(depth, 3.0).toDouble();
      final db = -maxDb * shaped;
      gain[i] = pow(10.0, db / 20.0).toDouble();
    }
    return gain;
  }

  Float64List _applyBandpass(Float64List input) {
    final out = Float64List(input.length);
    final f0 = frequency.toDouble();
    final q = (f0 / 300.0).clamp(0.5, 10.0);
    final omega = 2 * pi * f0 / sampleRate;
    final alpha = sin(omega) / (2 * q);
    final a0 = 1.0 + alpha;
    final b0 = alpha / a0;
    final b2 = -alpha / a0;
    final a1 = (-2 * cos(omega)) / a0;
    final a2 = (1.0 - alpha) / a0;

    double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (int i = 0; i < input.length; i++) {
      final x = input[i];
      final y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
      out[i] = y;
    }
    return out;
  }

  Float64List _buildBandNoise(int totalSamples) {
    final noise = Float64List(totalSamples);
    if (bandNoise <= 0) return noise;

    final rng = _Rng((seed ^ 0x165667B1) & 0x7FFFFFFF);
    final white = Float64List(totalSamples);
    for (int i = 0; i < totalSamples; i++) {
      white[i] = rng.next() * 2 - 1;
    }
    final filtered = _applyBandpass(white);

    double peak = 0;
    for (int i = 0; i < totalSamples; i++) {
      final a = filtered[i].abs();
      if (a > peak) peak = a;
    }
    if (peak > 1e-9) {
      for (int i = 0; i < totalSamples; i++) {
        noise[i] = filtered[i] / peak;
      }
    }
    return noise;
  }

  Float64List _buildQrn(int totalSamples) {
    final crackle = Float64List(totalSamples);
    if (qrn <= 0) return crackle;

    final rng = _Rng((seed ^ 0x27D4EB2F) & 0x7FFFFFFF);

    // Sparse impulse train with occasional dense bursts, shaped by the
    // receiver band-pass filter to remove high-frequency components.
    final impulse = Float64List(totalSamples);
    int burst = 0;
    for (int i = 0; i < totalSamples; i++) {
      if (burst > 0) {
        burst--;
      } else if (rng.next() < 0.00002) {
        burst = ((0.5 + rng.next() * 1.5) * sampleRate).toInt();
      }
      final density = burst > 0 ? 0.05 : 0.004;
      if (rng.next() < density) {
        double a = (rng.next() * 2 - 1) * 6.0;
        if (rng.next() < 0.2) a *= 3.0;
        impulse[i] = a;
      }
    }

    final q = (frequency.toDouble() / 300.0).clamp(0.5, 10.0);
    final filtered = _applyBandpass(impulse);
    for (int i = 0; i < totalSamples; i++) {
      crackle[i] = filtered[i] / q;
    }
    return crackle;
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

class _TimingResult {
  final List<_Segment> segments;
  final List<int> tokenStarts;
  final int totalSamples;
  const _TimingResult(this.segments, this.tokenStarts, this.totalSamples);
}

class _FistParams {
  final double dot;
  final double dash;
  final double dashSlow;
  final double gap;
  const _FistParams({
    required this.dot,
    required this.dash,
    required this.dashSlow,
    required this.gap,
  });
}

class _Rng {
  late int _state;
  _Rng(int seed) {
    var s = seed & 0x7FFFFFFF;
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF;
    _state = s == 0 ? 1 : s;
  }

  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}

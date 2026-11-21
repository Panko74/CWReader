import 'substitution.dart';

enum PlayerStatus { stopped, playing, paused }

enum Waveform { sine, square, triangle, sawtooth }

enum FistType { off, bug, straight, paddle, sideswiper }

class PlayerState {
  final String? filePath;
  final String? fileName;
  final String rawText;
  final int currentIndex;
  final int playedIndex;
  final PlayerStatus status;
  final Duration position;
  final int bookmarkIndex;
  final double progress;
  final String? error;

  const PlayerState({
    this.filePath,
    this.fileName,
    this.rawText = '',
    this.currentIndex = 0,
    this.playedIndex = -1,
    this.status = PlayerStatus.stopped,
    this.position = Duration.zero,
    this.bookmarkIndex = -1,
    this.progress = 0.0,
    this.error,
  });

  static const Object _sentinel = Object();

  PlayerState copyWith({
    String? filePath,
    String? fileName,
    String? rawText,
    int? currentIndex,
    int? playedIndex,
    PlayerStatus? status,
    Duration? position,
    int? bookmarkIndex,
    double? progress,
    Object? error = _sentinel,
  }) {
    return PlayerState(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      rawText: rawText ?? this.rawText,
      currentIndex: currentIndex ?? this.currentIndex,
      playedIndex: playedIndex ?? this.playedIndex,
      status: status ?? this.status,
      position: position ?? this.position,
      bookmarkIndex: bookmarkIndex ?? this.bookmarkIndex,
      progress: progress ?? this.progress,
      error: error == _sentinel ? this.error : error as String?,
    );
  }
}

class AppSettings {
  final int wpm;
  final int farnsworth;
  final double extraWordSpace;
  final int frequency;
  final Waveform waveform;
  final List<Substitution> substitutions;
  final double volume;
  final int envelopeMs;
  final bool showText;
  final double qsb;
  final double qsbPeriod;
  final double bandNoise;
  final double qrn;
  final FistType fistType;
  final double fistAmount;

  const AppSettings({
    this.wpm = 20,
    this.farnsworth = 0,
    this.extraWordSpace = 1.0,
    this.frequency = 600,
    this.waveform = Waveform.sine,
    this.substitutions = defaultSubstitutions,
    this.volume = 1.0,
    this.envelopeMs = 5,
    this.showText = false,
    this.qsb = 0.0,
    this.qsbPeriod = 20.0,
    this.bandNoise = 0.0,
    this.qrn = 0.0,
    this.fistType = FistType.off,
    this.fistAmount = 0.5,
  });

  static const defaultSubstitutions = [
    Substitution(from: '\u201C', to: '\u0022'),
    Substitution(from: '\u201D', to: '\u0022'),
    Substitution(from: '\u2018', to: "'"),
    Substitution(from: '\u2019', to: "'"),
    Substitution(from: '\u00AB', to: '-'),
    Substitution(from: '\u00BB', to: '-'),
    Substitution(from: '\u2014', to: '-'),
    Substitution(from: '\u2013', to: '-'),
    Substitution(from: '\u2026', to: '...'),
    Substitution(from: '&', to: 'e'),
  ];

  AppSettings copyWith({
    int? wpm,
    int? farnsworth,
    double? extraWordSpace,
    int? frequency,
    Waveform? waveform,
    List<Substitution>? substitutions,
    double? volume,
    int? envelopeMs,
    bool? showText,
    double? qsb,
    double? qsbPeriod,
    double? bandNoise,
    double? qrn,
    FistType? fistType,
    double? fistAmount,
  }) {
    return AppSettings(
      wpm: wpm ?? this.wpm,
      farnsworth: farnsworth ?? this.farnsworth,
      extraWordSpace: extraWordSpace ?? this.extraWordSpace,
      frequency: frequency ?? this.frequency,
      waveform: waveform ?? this.waveform,
      substitutions: substitutions ?? this.substitutions,
      volume: volume ?? this.volume,
      envelopeMs: envelopeMs ?? this.envelopeMs,
      showText: showText ?? this.showText,
      qsb: qsb ?? this.qsb,
      qsbPeriod: qsbPeriod ?? this.qsbPeriod,
      bandNoise: bandNoise ?? this.bandNoise,
      qrn: qrn ?? this.qrn,
      fistType: fistType ?? this.fistType,
      fistAmount: fistAmount ?? this.fistAmount,
    );
  }

  static List<Substitution> _mergeDefaults(List<Substitution> loaded) {
    final result = [...loaded];
    for (final def in AppSettings.defaultSubstitutions) {
      if (!result.any((s) => s.from == def.from)) {
        result.add(def);
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'wpm': wpm,
        'farnsworth': farnsworth,
        'extraWordSpace': extraWordSpace,
        'frequency': frequency,
        'waveform': waveform.index,
        'substitutions': substitutions.map((s) => s.toJson()).toList(),
        'volume': volume,
        'envelopeMs': envelopeMs,
        'showText': showText,
        'qsb': qsb,
        'qsbPeriod': qsbPeriod,
        'bandNoise': bandNoise,
        'qrn': qrn,
        'fistType': fistType.index,
        'fistAmount': fistAmount,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        wpm: json['wpm'] as int? ?? 20,
        farnsworth: json['farnsworth'] as int? ?? 0,
        extraWordSpace: (json['extraWordSpace'] as num?)?.toDouble() ?? 1.0,
        frequency: json['frequency'] as int? ?? 600,
        waveform: Waveform.values[json['waveform'] as int? ?? 0],
        substitutions: _mergeDefaults(
            (json['substitutions'] as List<dynamic>?)
                    ?.map((e) =>
                        Substitution.fromJson(e as Map<String, dynamic>))
                    .toList() ??
                AppSettings.defaultSubstitutions),
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        envelopeMs: json['envelopeMs'] as int? ?? 5,
        showText: json['showText'] as bool? ?? false,
        qsb: (json['qsb'] as num?)?.toDouble() ?? 0.0,
        qsbPeriod: (json['qsbPeriod'] as num?)?.toDouble() ?? 20.0,
        bandNoise: (json['bandNoise'] as num?)?.toDouble() ?? 0.0,
        qrn: (json['qrn'] as num?)?.toDouble() ?? 0.0,
        fistType: FistType.values[json['fistType'] as int? ?? 0],
        fistAmount: (json['fistAmount'] as num?)?.toDouble() ?? 0.5,
      );
}

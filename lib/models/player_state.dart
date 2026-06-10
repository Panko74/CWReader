import 'substitution.dart';

enum PlayerStatus { stopped, playing, paused }

enum Waveform { sine, square, triangle, sawtooth }

class PlayerState {
  final String? filePath;
  final String? fileName;
  final String rawText;
  final int currentIndex;
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

  const AppSettings({
    this.wpm = 20,
    this.farnsworth = 0,
    this.extraWordSpace = 1.0,
    this.frequency = 600,
    this.waveform = Waveform.sine,
    this.substitutions = defaultSubstitutions,
    this.volume = 1.0,
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
  ];

  AppSettings copyWith({
    int? wpm,
    int? farnsworth,
    double? extraWordSpace,
    int? frequency,
    Waveform? waveform,
    List<Substitution>? substitutions,
    double? volume,
  }) {
    return AppSettings(
      wpm: wpm ?? this.wpm,
      farnsworth: farnsworth ?? this.farnsworth,
      extraWordSpace: extraWordSpace ?? this.extraWordSpace,
      frequency: frequency ?? this.frequency,
      waveform: waveform ?? this.waveform,
      substitutions: substitutions ?? this.substitutions,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toJson() => {
        'wpm': wpm,
        'farnsworth': farnsworth,
        'extraWordSpace': extraWordSpace,
        'frequency': frequency,
        'waveform': waveform.index,
        'substitutions': substitutions.map((s) => s.toJson()).toList(),
        'volume': volume,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        wpm: json['wpm'] as int? ?? 20,
        farnsworth: json['farnsworth'] as int? ?? 0,
        extraWordSpace: (json['extraWordSpace'] as num?)?.toDouble() ?? 1.0,
        frequency: json['frequency'] as int? ?? 600,
        waveform: Waveform.values[json['waveform'] as int? ?? 0],
        substitutions: (json['substitutions'] as List<dynamic>?)
                ?.map((e) =>
                    Substitution.fromJson(e as Map<String, dynamic>))
                .toList() ??
            AppSettings.defaultSubstitutions,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      );
}

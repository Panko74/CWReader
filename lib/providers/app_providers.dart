import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart' hide PlayerState;
import '../models/player_state.dart';
import '../models/substitution.dart';
import '../services/file_service.dart';
import '../services/morse_converter.dart';
import '../services/audio_generator.dart';
import '../services/native_stream_player.dart';
import '../services/partial_wake_lock.dart';

final fileServiceProvider = Provider<FileService>((ref) => FileService());

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  Future<void>? _loadFuture;

  AppSettingsNotifier() : super(const AppSettings()) {
    _loadFuture = _load();
  }

  Future<void> ensureLoaded() async {
    await _loadFuture;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('app_settings');
    if (json != null) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        state = AppSettings.fromJson(map);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_settings', jsonEncode(state.toJson()));
  }

  void updateWpm(int wpm) {
    state = state.copyWith(wpm: wpm.clamp(5, 60));
    _save();
  }

  void updateFarnsworth(int ms) {
    state = state.copyWith(farnsworth: ms.clamp(0, 1000));
    _save();
  }

  void updateExtraWordSpace(double multiplier) {
    state = state.copyWith(extraWordSpace: multiplier.clamp(1.0, 5.0));
    _save();
  }

  void updateFrequency(int freq) {
    state = state.copyWith(frequency: freq.clamp(400, 900));
    _save();
  }

  void updateWaveform(Waveform wf) {
    state = state.copyWith(waveform: wf);
    _save();
  }

  void updateVolume(double vol) {
    state = state.copyWith(volume: vol.clamp(0.0, 1.0));
    _save();
  }

  void updateEnvelope(int ms) {
    state = state.copyWith(envelopeMs: ms.clamp(0, 50));
    _save();
  }

  void updateShowText(bool show) {
    state = state.copyWith(showText: show);
    _save();
  }

  void updateSubstitutions(List<Substitution> subs) {
    state = state.copyWith(substitutions: subs);
    _save();
  }

  void addSubstitution(Substitution sub) {
    state = state.copyWith(substitutions: [...state.substitutions, sub]);
    _save();
  }

  void removeSubstitution(int index) {
    final subs = [...state.substitutions];
    if (index < subs.length) {
      subs.removeAt(index);
      state = state.copyWith(substitutions: subs);
      _save();
    }
  }

  void toggleSubstitution(int index) {
    final subs = [...state.substitutions];
    if (index < subs.length) {
      subs[index] = subs[index].copyWith(enabled: !subs[index].enabled);
      state = state.copyWith(substitutions: subs);
      _save();
    }
  }
}

final processedTextProvider = Provider<String>((ref) {
  final text = ref.watch(textContentProvider);
  final settings = ref.watch(appSettingsProvider);
  final converter = MorseConverter(substitutions: settings.substitutions);
  return converter.applySubstitutions(text);
});

final morseTokensProvider = Provider<List<String>>((ref) {
  final text = ref.watch(processedTextProvider);
  return MorseConverter().textToTokens(text);
});

final tokenCountProvider = Provider<int>((ref) {
  return ref.watch(morseTokensProvider).length;
});

final displayTextProvider = Provider<String>((ref) {
  return ref.watch(processedTextProvider);
});

final tokenToCharIndexProvider = Provider<List<int>>((ref) {
  final text = ref.watch(processedTextProvider);
  return MorseConverter().textToTokensWithSource(text).sourceIndices;
});

final textContentProvider = StateProvider<String>((ref) => '');

final fileNameProvider = StateProvider<String>((ref) => '');

const _lastPositionsKey = 'last_positions';
const _recentFilesKey = 'recent_files';
const _maxRecentFiles = 10;
const _bookmarksKey = 'bookmarks';

final _recentFilesVersionProvider = StateProvider<int>((ref) => 0);
final _lastPosVersionProvider = StateProvider<int>((ref) => 0);

final recentFilesProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  ref.watch(_recentFilesVersionProvider);
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_recentFilesKey);
  if (json == null) return [];
  final list = (jsonDecode(json) as List<dynamic>)
      .map((e) => Map<String, String>.from(e as Map))
      .toList();
  final valid = <Map<String, String>>[];
  for (final e in list) {
    final path = e['path'];
    if (path != null && await File(path).exists()) {
      valid.add(e);
    }
  }
  return valid;
});

final lastPositionsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.watch(_lastPosVersionProvider);
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_lastPositionsKey);
  if (json == null) return {};
  return (jsonDecode(json) as Map).map((k, v) => MapEntry(k as String, v as int));
});

final bookmarksProvider = FutureProvider<Map<String, int>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_bookmarksKey);
  if (json == null) return {};
  return (jsonDecode(json) as Map).map((k, v) => MapEntry(k as String, v as int));
});

Future<void> removeRecentFile(String path) async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_recentFilesKey);
  if (json == null) return;
  final list = (jsonDecode(json) as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  list.removeWhere((e) => e['path'] == path);
  await prefs.setString(_recentFilesKey, jsonEncode(list));

  for (final key in [_lastPositionsKey, _bookmarksKey]) {
    final keyJson = prefs.getString(key);
    if (keyJson == null) continue;
    final map = Map<String, dynamic>.from(jsonDecode(keyJson) as Map);
    if (map.remove(path) != null) {
      await prefs.setString(key, jsonEncode(map));
    }
  }

  final docs = await getApplicationDocumentsDirectory();
  final booksDir = Directory('${docs.path}/books').absolute.path;
  final file = File(path).absolute.path;
  if (file.startsWith(booksDir)) {
    try {
      if (await File(file).exists()) {
        await File(file).delete();
      }
    } catch (_) {}
  }
}

Future<void> _addRecentFileHelper(Ref ref, String path, String name) async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_recentFilesKey);
  List<Map<String, dynamic>> list;
  if (json != null) {
    list = (jsonDecode(json) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    list.removeWhere((e) => e['path'] == path);
  } else {
    list = [];
  }
  list.insert(0, {'path': path, 'name': name});
  if (list.length > _maxRecentFiles) list = list.sublist(0, _maxRecentFiles);
  await prefs.setString(_recentFilesKey, jsonEncode(list));
  ref.read(_recentFilesVersionProvider.notifier).state++;
}

final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Ref _ref;
  AudioPlayer? _audioPlayer;
  Timer? _progressTimer;
  Timer? _saveTimer;
  List<String>? _allTokens;
  bool _chunkPending = false;
  Uint8List? _nextWav;
  int _nextWavFrom = -1;

  final NativeStreamPlayer _stream = NativeStreamPlayer();
  bool _streamActive = false;
  int _streamGen = 0;
  bool _streamInitialized = false;
  int _streamFramesFed = 0;
  int _streamBaseHead = 0;
  bool _streamFinished = false;
  DateTime? _streamFinishedAt;
  Uint8List? _streamPending;
  int _streamPendingOff = 0;
  int _streamPendingTokens = 0;
  List<int>? _streamTokenPositions;
  int _streamBaseToken = 0;
  int _totalStreamSamples = 0;

  static const int _streamSampleRate = 44100;
  static const int _streamFeedCapFrames = _streamSampleRate * 2;
  static const int _streamSliceFrames = _streamSampleRate;
  static const Duration _streamSleep = Duration(milliseconds: 80);

  static bool get _useNative => NativeStreamPlayer.available;

  Future<void> _lastOp = Future<void>.value();

  Future<void> _runSerialized(Future<void> Function() op) {
    final next = _lastOp.then((_) => op());
    _lastOp = next.then((_) {}, onError: (_) {});
    return next;
  }

  PlayerNotifier(this._ref) : super(const PlayerState());

  @override
  void dispose() {
    _cleanup();
    PartialWakeLock.disable();
    super.dispose();
  }

  void _cleanup() {
    _progressTimer?.cancel();
    _saveTimer?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _allTokens = null;
    _chunkPending = false;
    _nextWav = null;
    _nextWavFrom = -1;
    _stopStreamSilently();
  }

  void _updateWakeLock() {
    if (state.status == PlayerStatus.playing) {
      PartialWakeLock.enable();
    } else {
      PartialWakeLock.disable();
    }
  }

  void _stopStreamSilently() {
    _streamActive = false;
    _streamGen++;
    _streamInitialized = false;
    _streamFinished = false;
    _streamFinishedAt = null;
    _clearStreamPending();
    _streamTokenPositions = null;
    _streamBaseToken = 0;
    _totalStreamSamples = 0;
    _stream.stop();
  }

  void _clearStreamPending() {
    _streamPending = null;
    _streamPendingOff = 0;
    _streamPendingTokens = 0;
  }

  void _prepareStreamIndexing() {
    _streamTokenPositions = null;
    _streamBaseToken = 0;
    _totalStreamSamples = 0;
    if (_allTokens == null || _allTokens!.isEmpty) return;
    final from = state.currentIndex;
    if (from >= _allTokens!.length) return;
    final remaining = _allTokens!.skip(from).toList();
    final generator = AudioGenerator.fromSettings(_ref.read(appSettingsProvider));
    _streamTokenPositions =
        AudioGenerator.computeTokenSamplePositions(remaining, generator);
    _streamBaseToken = from;
    _totalStreamSamples = generator.sampleCountFor(remaining);
  }

  void _cancelPlayback() {
    _progressTimer?.cancel();
    _saveTimer?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _chunkPending = false;
    _nextWav = null;
    _nextWavFrom = -1;
  }

  Future<void> _autoSave() async {
    final path = state.filePath;
    final pos = state.currentIndex;
    if (path == null) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_lastPositionsKey);
    final map = json != null
        ? Map<String, dynamic>.from(jsonDecode(json) as Map)
        : <String, dynamic>{};
    map[path] = pos;
    await prefs.setString(_lastPositionsKey, jsonEncode(map));
    _ref.read(_lastPosVersionProvider.notifier).state++;
  }

  Future<void> loadFile(String filePath, String fileName, {int? position}) async {
    _cleanup();
    final service = _ref.read(fileServiceProvider);
    String content;
    try {
      content = await service.readFileContent(filePath);
    } catch (e) {
      state = state.copyWith(
        filePath: filePath,
        fileName: fileName,
        status: PlayerStatus.stopped,
        error: e.toString(),
      );
      _ref.read(fileNameProvider.notifier).state = fileName;
      return;
    }

    final startPos = position ?? await _lastPositionForFile(filePath);

    state = state.copyWith(
      filePath: filePath,
      fileName: fileName,
      rawText: content,
      currentIndex: startPos,
      status: PlayerStatus.stopped,
      position: Duration.zero,
      progress: 0.0,
      error: null,
      bookmarkIndex: -1,
    );

    _ref.read(textContentProvider.notifier).state = content;
    _ref.read(fileNameProvider.notifier).state = fileName;
    _addRecentFileHelper(_ref, filePath, fileName);
    _autoSave();
    _loadBookmarkForFile(filePath);
  }

  Future<int> _lastPositionForFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_lastPositionsKey);
    if (json == null) return 0;
    final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
    return map[path] as int? ?? 0;
  }

  Future<void> play() {
    return _runSerialized(_play);
  }

  Future<void> _play() async {
    await _ref.read(appSettingsProvider.notifier).ensureLoaded();

    if (_useNative) {
      await _playNative();
      return;
    }

    if (state.status == PlayerStatus.paused && _audioPlayer != null) {
      await _audioPlayer!.resume();
      state = state.copyWith(status: PlayerStatus.playing);
      _updateWakeLock();
      _startProgressTimer();
      return;
    }

    _allTokens = _ref.read(morseTokensProvider);
    if (_allTokens == null || _allTokens!.isEmpty) {
      state = state.copyWith(
        status: PlayerStatus.stopped,
        error: 'Nessun carattere Morse riconoscibile trovato nel testo.',
      );
      _updateWakeLock();
      return;
    }

    if (state.currentIndex >= _allTokens!.length) {
      state = state.copyWith(currentIndex: 0);
    }

    _playNextChunk();
  }

  Future<void> _playNative() async {
    if (state.status == PlayerStatus.paused && _streamInitialized) {
      await _stream.reset();
      _clearStreamPending();
      _streamBaseHead = await _stream.playedFrames();
      _streamFramesFed = 0;
      _streamFinished = false;
      _streamFinishedAt = null;
      final wordStart = _wordStartIndex(state.currentIndex);
      if (wordStart >= 0) {
        state = state.copyWith(currentIndex: wordStart, playedIndex: wordStart);
      }
      _prepareStreamIndexing();
      state = state.copyWith(status: PlayerStatus.playing);
      _updateWakeLock();
      _startProgressTimer();
      _startStreamPump();
      return;
    }

    _allTokens = _ref.read(morseTokensProvider);
    if (_allTokens == null || _allTokens!.isEmpty) {
      state = state.copyWith(
        status: PlayerStatus.stopped,
        error: 'Nessun carattere Morse riconoscibile trovato nel testo.',
      );
      _updateWakeLock();
      return;
    }

    if (state.currentIndex >= _allTokens!.length) {
      state = state.copyWith(currentIndex: 0);
    }

    await _stream.stop();
    final ok =
        await _stream.init(sampleRate: _streamSampleRate, channels: 1);
    if (!ok) {
      state = state.copyWith(
        status: PlayerStatus.stopped,
        error: 'Avvio streaming audio non riuscito.',
      );
      _updateWakeLock();
      return;
    }
    _streamInitialized = true;
    _clearStreamPending();
    _streamBaseHead = await _stream.playedFrames();
    _streamFramesFed = 0;
    _streamFinished = false;
    _streamFinishedAt = null;
    _prepareStreamIndexing();
    state = state.copyWith(
      status: PlayerStatus.playing,
      error: null,
      playedIndex: state.currentIndex,
      progress: (state.currentIndex / _allTokens!.length).clamp(0.0, 1.0),
    );
    _updateWakeLock();
    _startProgressTimer();
    _startStreamPump();
  }

  Future<void> _startStreamPump() async {
    _streamActive = true;
    final gen = ++_streamGen;
    while (_streamActive && gen == _streamGen) {
      if (state.status != PlayerStatus.playing) break;
      if (_streamFinished) break;
      final played = await _stream.playedFrames();
      if (!_streamActive || gen != _streamGen) break;
      if (state.status != PlayerStatus.playing) break;
      final inFlight = _streamFramesFed - (played - _streamBaseHead);
      if (inFlight < _streamFeedCapFrames) {
        final more = await _feedStreamAhead(gen);
        if (!_streamActive || gen != _streamGen) break;
        if (!more) {
          _streamFinished = true;
          _streamFinishedAt = DateTime.now();
          break;
        }
      }
      await Future<void>.delayed(_streamSleep);
    }
  }

  Future<bool> _feedStreamAhead(int gen) async {
    while (true) {
      if (!_streamActive || gen != _streamGen) return _hasMoreTokens();
      if (_streamPending == null) {
        if (_allTokens == null || state.currentIndex >= _allTokens!.length) {
          return false;
        }
        final from = state.currentIndex;
        final chunk = _buildWordAlignedChunk(from);
        if (chunk.isEmpty) return false;
        final settings = _ref.read(appSettingsProvider);
        final generator = AudioGenerator.fromSettings(settings);
        final pcm = generator.tokensToPcm(chunk);
        _streamPending =
            pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes);
        _streamPendingOff = 0;
        _streamPendingTokens = chunk.length;
      }
      final bytes = _streamPending!;
      final sliceBytes = _streamSliceFrames * 2;
      while (_streamPendingOff < bytes.length) {
        if (!_streamActive || gen != _streamGen) return _hasMoreTokens();
        final played = await _stream.playedFrames();
        if (!_streamActive || gen != _streamGen) return _hasMoreTokens();
        if (_streamFramesFed - (played - _streamBaseHead) >=
            _streamFeedCapFrames) {
          return _hasMoreTokens();
        }
        final end = math.min(_streamPendingOff + sliceBytes, bytes.length);
        await _stream.write(Uint8List.sublistView(bytes, _streamPendingOff, end));
        _streamFramesFed += (end - _streamPendingOff) ~/ 2;
        _streamPendingOff = end;
      }
      _streamPending = null;
      if (_allTokens == null) return _hasMoreTokens();
      state =
          state.copyWith(currentIndex: state.currentIndex + _streamPendingTokens);
      if (state.currentIndex >= _allTokens!.length) return false;
    }
  }

  int _wordStartIndex(int index) {
    if (_allTokens == null || _allTokens!.isEmpty) return -1;
    if (index >= _allTokens!.length) index = _allTokens!.length;
    while (index < _allTokens!.length &&
        (_allTokens![index] == ' ' || _allTokens![index] == '/')) {
      index++;
    }
    var i = index;
    while (i > 0 &&
        _allTokens![i - 1] != ' ' &&
        _allTokens![i - 1] != '/') {
      i--;
    }
    return i;
  }

  bool _hasMoreTokens() {
    return _allTokens != null && state.currentIndex < _allTokens!.length;
  }

  Future<void> _completeStream() async {
    final len = _allTokens?.length ?? 0;
    _streamActive = false;
    _streamGen++;
    _streamInitialized = false;
    _progressTimer?.cancel();
    _saveTimer?.cancel();
    _clearStreamPending();
    _streamTokenPositions = null;
    _streamBaseToken = 0;
    _totalStreamSamples = 0;
    await _stream.stop();
    _allTokens = null;
    state = state.copyWith(
      status: PlayerStatus.stopped,
      currentIndex: len,
      playedIndex: len,
      progress: 1.0,
    );
    _updateWakeLock();
    _autoSave();
  }

  Future<void> _playNextChunk() async {
    if (_allTokens == null) return;

    final fromIndex = state.currentIndex;
    final chunk = _buildWordAlignedChunk(fromIndex);
    if (chunk.isEmpty) {
      _cancelPlayback();
      state = state.copyWith(
        status: PlayerStatus.stopped,
        progress: 1.0,
        currentIndex: _allTokens!.length,
      );
      _updateWakeLock();
      return;
    }

    Uint8List wav;
    if (_nextWav != null && _nextWavFrom == fromIndex) {
      wav = _nextWav!;
      _nextWav = null;
      _nextWavFrom = -1;
    } else {
      _nextWav = null;
      final settings = _ref.read(appSettingsProvider);
      final generator = AudioGenerator.fromSettings(settings);
      wav = generator.tokensToWav(chunk);
    }

    _cancelPlayback();
    _audioPlayer = AudioPlayer();
    _chunkPending = true;

    _audioPlayer!.onPlayerComplete.listen((_) {
      if (!_chunkPending) return;
      _chunkPending = false;
      final newIndex = fromIndex + chunk.length;
      if (_allTokens == null || newIndex >= _allTokens!.length) {
        _cancelPlayback();
        state = state.copyWith(
          status: PlayerStatus.stopped,
          currentIndex: _allTokens?.length ?? 0,
          progress: 1.0,
        );
        _updateWakeLock();
        return;
      }
      state = state.copyWith(currentIndex: newIndex);
      _playNextChunk();
    });

    await _audioPlayer!.play(BytesSource(wav));
    state = state.copyWith(status: PlayerStatus.playing);
    _updateWakeLock();
    _startProgressTimer();

    _preGenerateNext(fromIndex + chunk.length);
  }

  List<String> _buildWordAlignedChunk(int fromIndex) {
    const minTokens = 20;
    const maxTokens = 50;
    if (fromIndex >= _allTokens!.length) return [];
    var end = fromIndex + minTokens;
    if (end >= _allTokens!.length) return _allTokens!.skip(fromIndex).toList();
    for (int i = end; i < fromIndex + maxTokens && i < _allTokens!.length; i++) {
      if (_allTokens![i] == ' ') {
        end = i + 1;
        break;
      }
    }
    return _allTokens!.skip(fromIndex).take(end - fromIndex).toList();
  }

  Future<void> _preGenerateNext(int startIndex) async {
    if (_allTokens == null) return;
    final chunk = _buildWordAlignedChunk(startIndex);
    if (chunk.isEmpty) return;
    final settings = _ref.read(appSettingsProvider);
    final generator = AudioGenerator.fromSettings(settings);
    _nextWav = generator.tokensToWav(chunk);
    _nextWavFrom = startIndex;
  }

  void requestRegen() {
    if (state.status != PlayerStatus.playing || _allTokens == null) return;
    if (_useNative) {
      _regenNative();
      return;
    }
    _nextWav = null;
    _nextWavFrom = -1;
    _cancelPlayback();
    _playNextChunk();
  }

  Future<void> _regenNative() async {
    _streamActive = false;
    _streamGen++;
    await _stream.reset();
    _clearStreamPending();
    _streamBaseHead = await _stream.playedFrames();
    _streamFramesFed = 0;
    _streamFinished = false;
    _streamFinishedAt = null;
    _prepareStreamIndexing();
    _startStreamPump();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _progressTick();
    });
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _autoSave();
    });
  }

  Future<void> _progressTick() async {
    if (_useNative) {
      if (state.status != PlayerStatus.playing) return;
      final played = await _stream.playedFrames();
      final rel = played - _streamBaseHead;
      if (_streamFinished) {
        final threshold = _streamFramesFed;
        final expired = _streamFinishedAt != null &&
            DateTime.now().difference(_streamFinishedAt!) >=
                const Duration(seconds: 4);
        if (expired || rel >= threshold) {
          await _completeStream();
          return;
        }
      }
      var playedIndex = state.currentIndex;
      if (_streamTokenPositions != null && _streamTokenPositions!.isNotEmpty) {
        final pos = rel.clamp(0, _totalStreamSamples).toInt();
        final idx =
            AudioGenerator.findTokenIndex(_streamTokenPositions!, pos);
        playedIndex = _streamBaseToken + idx;
      }
      state = state.copyWith(
        progress: _allTokens == null || _allTokens!.isEmpty
            ? 0.0
            : (state.currentIndex / _allTokens!.length).clamp(0.0, 1.0),
        playedIndex: playedIndex,
      );
      return;
    }
    if (state.status != PlayerStatus.playing || _allTokens == null) return;
    state = state.copyWith(
      progress: _allTokens!.isEmpty
          ? 0.0
          : (state.currentIndex / _allTokens!.length).clamp(0.0, 1.0),
    );
  }

  Future<void> pause() {
    return _runSerialized(_pause);
  }

  Future<void> _pause() async {
    if (_useNative) {
      _streamActive = false;
      _streamGen++;
      await _stream.pause();
      _progressTimer?.cancel();
      _saveTimer?.cancel();
      state = state.copyWith(status: PlayerStatus.paused);
      _updateWakeLock();
      _autoSave();
      return;
    }
    await _audioPlayer?.pause();
    _progressTimer?.cancel();
    _saveTimer?.cancel();
    state = state.copyWith(status: PlayerStatus.paused);
    _updateWakeLock();
    _autoSave();
  }

  Future<void> stop() {
    return _runSerialized(_stop);
  }

  Future<void> _stop() async {
    if (_useNative) {
      _stopStreamSilently();
      _allTokens = null;
      state = state.copyWith(
        status: PlayerStatus.stopped,
        position: Duration.zero,
        progress: 0.0,
        currentIndex: 0,
      );
      _updateWakeLock();
      _autoSave();
      return;
    }
    _cancelPlayback();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _allTokens = null;
    state = state.copyWith(
      status: PlayerStatus.stopped,
      position: Duration.zero,
      progress: 0.0,
      currentIndex: 0,
    );
    _updateWakeLock();
    _autoSave();
  }

  Future<void> seekToProgress(double progress) async {
    if (_allTokens == null || _allTokens!.isEmpty) return;
    final newIndex = (progress * _allTokens!.length).round().clamp(0, _allTokens!.length - 1);
    await _seek(newIndex);
  }

  Future<void> _seek(int newIndex) {
    return _runSerialized(() => _seekInternal(newIndex));
  }

  Future<void> _seekInternal(int newIndex) async {
    if (_allTokens == null) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= _allTokens!.length) newIndex = _allTokens!.length - 1;
    final newProgress = _allTokens!.isEmpty
        ? 0.0
        : (newIndex / _allTokens!.length).clamp(0.0, 1.0);
    if (_useNative) {
      final wasPlaying = state.status == PlayerStatus.playing;
      final wasPaused = state.status == PlayerStatus.paused;
      _streamActive = false;
      _streamGen++;
      state = state.copyWith(
        currentIndex: newIndex,
        playedIndex: newIndex,
        progress: newProgress,
      );
      if (wasPlaying) {
        await _stream.reset();
        _clearStreamPending();
        _streamBaseHead = await _stream.playedFrames();
        _streamFramesFed = 0;
        _streamFinished = false;
        _streamFinishedAt = null;
        _prepareStreamIndexing();
        state = state.copyWith(status: PlayerStatus.playing);
        _startStreamPump();
      } else if (wasPaused && _streamInitialized) {
        await _stream.flush();
        _clearStreamPending();
        _streamBaseHead = await _stream.playedFrames();
        _streamFramesFed = 0;
        _streamFinished = false;
        _streamFinishedAt = null;
        _prepareStreamIndexing();
      }
      return;
    }
    final wasPlaying = state.status == PlayerStatus.playing;
    _cancelPlayback();
    _audioPlayer?.stop();
    state = state.copyWith(currentIndex: newIndex, progress: newProgress);
    if (wasPlaying) {
      _chunkPending = true;
      _playNextChunk();
    }
  }

  Future<void> seekForward({int words = 10}) async {
    if (_allTokens == null) return;
    final current = state.currentIndex;
    var newIndex = current;
    var found = 0;
    for (int i = current + 1; i < _allTokens!.length; i++) {
      if (_allTokens![i] == ' ') {
        found++;
        if (found >= words) { newIndex = i + 1; break; }
      }
    }
    if (newIndex >= _allTokens!.length) newIndex = _allTokens!.length - 1;
    await _seek(newIndex);
  }

  Future<void> seekBackward({int words = 10}) async {
    if (_allTokens == null) return;
    final current = state.currentIndex;
    var newIndex = current;
    var found = 0;
    int start = current - 1;
    if (start >= 0 && _allTokens![start] == ' ') {
      start--;
    }
    for (int i = start; i >= 0; i--) {
      if (_allTokens![i] == ' ') {
        found++;
        if (found >= words) { newIndex = i + 1; break; }
      }
    }
    if (found < words) newIndex = 0;
    await _seek(newIndex);
  }

  void setBookmark() {
    state = state.copyWith(bookmarkIndex: state.currentIndex);
    saveBookmark();
  }

  Future<void> goToBookmark() async {
    if (state.bookmarkIndex < 0) return;
    await _seek(state.bookmarkIndex);
  }

  void clearBookmark() {
    state = state.copyWith(bookmarkIndex: -1);
    final path = state.filePath;
    if (path == null) return;
    saveBookmark();
  }

  Future<void> saveBookmark() async {
    final path = state.filePath;
    if (path == null) return;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_bookmarksKey);
    final map = json != null
        ? Map<String, dynamic>.from(jsonDecode(json) as Map)
        : <String, dynamic>{};
    map[path] = state.bookmarkIndex >= 0 ? state.currentIndex : -1;
    await prefs.setString(_bookmarksKey, jsonEncode(map));
  }

  Future<void> _loadBookmarkForFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_bookmarksKey);
    if (json == null) return;
    final map = Map<String, dynamic>.from(jsonDecode(json) as Map);
    final index = map[path] as int? ?? -1;
    if (index >= 0) {
      state = state.copyWith(bookmarkIndex: index);
    }
  }
}

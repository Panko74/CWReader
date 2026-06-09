import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart' hide PlayerState;
import '../models/player_state.dart';
import '../models/substitution.dart';
import '../services/file_service.dart';
import '../services/morse_converter.dart';
import '../services/audio_generator.dart';

final fileServiceProvider = Provider<FileService>((ref) => FileService());

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
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
  return (jsonDecode(json) as List<dynamic>)
      .map((e) => Map<String, String>.from(e as Map))
      .toList();
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

  PlayerNotifier(this._ref) : super(const PlayerState());

  @override
  void dispose() {
    _cleanup();
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

  Future<void> play() async {
    if (state.status == PlayerStatus.paused && _audioPlayer != null) {
      await _audioPlayer!.resume();
      state = state.copyWith(status: PlayerStatus.playing);
      _startProgressTimer();
      return;
    }

    _allTokens = _ref.read(morseTokensProvider);
    if (_allTokens == null || _allTokens!.isEmpty) {
      state = state.copyWith(
        status: PlayerStatus.stopped,
        error: 'Nessun carattere Morse riconoscibile trovato nel testo.',
      );
      return;
    }

    if (state.currentIndex >= _allTokens!.length) {
      state = state.copyWith(currentIndex: 0);
    }

    _playNextChunk();
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
        return;
      }
      state = state.copyWith(currentIndex: newIndex);
      _playNextChunk();
    });

    await _audioPlayer!.play(BytesSource(wav));
    state = state.copyWith(status: PlayerStatus.playing);
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
    const chunkSize = 30;
    final chunk = _allTokens!.skip(startIndex).take(chunkSize).toList();
    if (chunk.isEmpty) return;
    final settings = _ref.read(appSettingsProvider);
    final generator = AudioGenerator.fromSettings(settings);
    _nextWav = generator.tokensToWav(chunk);
    _nextWavFrom = startIndex;
  }

  void requestRegen() {
    if (state.status != PlayerStatus.playing || _allTokens == null) return;
    _nextWav = null;
    _nextWavFrom = -1;
    _cancelPlayback();
    _playNextChunk();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (state.status != PlayerStatus.playing || _allTokens == null) return;
      state = state.copyWith(
        progress: _allTokens!.isEmpty
            ? 0.0
            : (state.currentIndex / _allTokens!.length).clamp(0.0, 1.0),
      );
    });
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _autoSave();
    });
  }

  Future<void> pause() async {
    await _audioPlayer?.pause();
    _progressTimer?.cancel();
    _saveTimer?.cancel();
    state = state.copyWith(status: PlayerStatus.paused);
    _autoSave();
  }

  Future<void> stop() async {
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
    _autoSave();
  }

  Future<void> _seek(int newIndex) async {
    if (_allTokens == null) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex >= _allTokens!.length) newIndex = _allTokens!.length - 1;
    final wasPlaying = state.status == PlayerStatus.playing;
    _cancelPlayback();
    _audioPlayer?.stop();
    state = state.copyWith(currentIndex: newIndex);
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
    for (int i = current - 1; i >= 0; i--) {
      if (_allTokens![i] == ' ') {
        found++;
        if (found >= words) { newIndex = i + 1; break; }
      }
    }
    if (newIndex < 0) newIndex = 0;
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

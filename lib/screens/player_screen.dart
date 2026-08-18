import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/player_state.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double? _dragProgress;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final settings = ref.watch(appSettingsProvider);
    final shownProgress = _dragProgress ?? state.progress;
    final shownPos =
        state.playedIndex >= 0 ? state.playedIndex : state.currentIndex;
    final displayText = ref.watch(displayTextProvider);
    final charIndices = ref.watch(tokenToCharIndexProvider);
    final textCharIndex = (shownPos >= 0 && shownPos < charIndices.length)
        ? charIndices[shownPos]
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.fileName ?? 'Riproduzione',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Apri un altro file',
            onPressed: () => _openFile(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Conversione Morse',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${state.playedIndex >= 0 ? state.playedIndex : state.currentIndex} caratteri processati',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16),
                        activeTrackColor:
                            Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        thumbColor:
                            Theme.of(context).colorScheme.primary,
                        trackHeight: 8,
                      ),
                      child: Slider(
                        value: shownProgress.clamp(0.0, 1.0),
                        onChanged: state.filePath != null
                            ? (v) => setState(() => _dragProgress = v)
                            : null,
                        onChangeEnd: state.filePath != null
                            ? (v) {
                                setState(() => _dragProgress = null);
                                ref
                                    .read(playerProvider.notifier)
                                    .seekToProgress(v);
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(shownProgress * 100).toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (state.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.error!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _BookmarkControls(state: state),
            if (state.filePath != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(appSettingsProvider.notifier)
                    .updateShowText(!settings.showText),
                icon: Icon(
                  settings.showText ? Icons.visibility_off : Icons.visibility,
                ),
                label: Text(
                  settings.showText ? 'Nascondi testo' : 'Mostra testo',
                ),
              ),
            ],
            if (settings.showText && state.filePath != null) ...[
              const SizedBox(height: 12),
              _TextReaderBox(
                text: displayText,
                position: textCharIndex,
              ),
            ],
            const Spacer(),
            _PlaybackControls(state: state),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile() async {
    final service = ref.read(fileServiceProvider);
    final ok = await service.requestStoragePermission();
    if (!ok) return;
    final file = await service.pickFile();
    if (file == null || !mounted) return;
    try {
      final imported = await service.importBook(file);
      if (!mounted) return;
      await ref
          .read(playerProvider.notifier)
          .loadFile(imported.path!, imported.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }
}

class _PlaybackControls extends ConsumerWidget {
  final PlayerState state;

  const _PlaybackControls({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = state.status == PlayerStatus.playing;
    final isPaused = state.status == PlayerStatus.paused;
    final hasFile = state.filePath != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          tooltip: 'Indietro 10 parole',
          onPressed: hasFile
              ? () => ref.read(playerProvider.notifier).seekBackward()
              : null,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.replay_10),
          tooltip: '-1 parola',
          onPressed: hasFile
              ? () => ref.read(playerProvider.notifier).seekBackward(words: 1)
              : null,
        ),
        const SizedBox(width: 16),
        FilledButton(
          onPressed: hasFile
              ? () {
                  final notifier = ref.read(playerProvider.notifier);
                  if (isPlaying) {
                    notifier.pause();
                  } else if (isPaused) {
                    notifier.play();
                  } else {
                    notifier.play();
                  }
                }
              : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            size: 36,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.forward_10),
          tooltip: '+1 parola',
          onPressed: hasFile
              ? () => ref.read(playerProvider.notifier).seekForward(words: 1)
              : null,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_next),
          tooltip: 'Avanti 10 parole',
          onPressed: hasFile
              ? () => ref.read(playerProvider.notifier).seekForward()
              : null,
        ),
      ],
    );
  }
}

class _TextReaderBox extends StatelessWidget {
  final String text;
  final int position;

  const _TextReaderBox({required this.text, required this.position});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 18, color: scheme.onSurface);
    return Container(
      height: 48,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRect(
        child: CustomPaint(
          painter: _KaraokePainter(
            text: text.replaceAll('\n', ' '),
            position: position,
            style: style,
            underlineColor: scheme.primary,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _KaraokePainter extends CustomPainter {
  final String text;
  final int position;
  final TextStyle style;
  final Color underlineColor;

  _KaraokePainter({
    required this.text,
    required this.position,
    required this.style,
    required this.underlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final start = (position - 30).clamp(0, text.length);
    final end = (position + 70).clamp(start, text.length);
    final slice = text.substring(start, end);
    final rel = position - start;

    final tp = TextPainter(
      text: TextSpan(text: slice, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final pos = rel.clamp(0, slice.length);
    final caret = tp.getOffsetForCaret(TextPosition(offset: pos), Rect.zero);
    final y = (size.height - tp.height) / 2;
    final underlineX = size.width * 0.5;
    final dx = underlineX - caret.dx;

    canvas.save();
    canvas.translate(dx, y);
    tp.paint(canvas, Offset.zero);
    canvas.restore();

    final next = tp.getOffsetForCaret(
      TextPosition(offset: (pos + 1).clamp(0, slice.length)),
      Rect.zero,
    );
    final w = math.max(next.dx - caret.dx, 3.0);
    final underlinePaint = Paint()
      ..color = underlineColor
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(underlineX, y + tp.height),
      Offset(underlineX + w, y + tp.height),
      underlinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KaraokePainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.position != position;
}

class _BookmarkControls extends ConsumerWidget {
  final PlayerState state;

  const _BookmarkControls({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasBookmark = state.bookmarkIndex >= 0;
    final hasFile = state.filePath != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasBookmark) ...[
          ActionChip(
            avatar: const Icon(Icons.bookmark, size: 18),
            label: const Text('Vai a segnalibro'),
            onPressed: hasFile
                ? () => ref.read(playerProvider.notifier).goToBookmark()
                : null,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.bookmark_remove),
            tooltip: 'Rimuovi segnalibro',
            onPressed: hasFile
                ? () => ref.read(playerProvider.notifier).clearBookmark()
                : null,
          ),
        ] else ...[
          ActionChip(
            avatar: const Icon(Icons.bookmark_border, size: 18),
            label: const Text('Imposta segnalibro'),
            onPressed: hasFile
                ? () => ref.read(playerProvider.notifier).setBookmark()
                : null,
          ),
        ],
      ],
    );
  }
}

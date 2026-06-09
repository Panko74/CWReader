import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/player_state.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);

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
            onPressed: () => _openFile(context, ref),
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
                      '${state.currentIndex} caratteri processati',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: state.progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(state.progress * 100).toStringAsFixed(1)}%',
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
            const Spacer(),
            _PlaybackControls(state: state),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    final service = ref.read(fileServiceProvider);
    final ok = await service.requestStoragePermission();
    if (!ok) return;
    final file = await service.pickFile();
    if (file == null || !context.mounted) return;
    try {
      await ref.read(playerProvider.notifier).loadFile(file.path!, file.name);
    } catch (e) {
      if (context.mounted) {
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

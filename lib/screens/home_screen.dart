import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = ref.watch(fileNameProvider);
    final recentFiles = ref.watch(recentFilesProvider).valueOrNull ?? [];
    final lastPositions = ref.watch(lastPositionsProvider).valueOrNull ?? {};
    final bookmarks = ref.watch(bookmarksProvider).valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('CWReader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Carica un file EPUB o TXT\nper convertirlo in codice Morse',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Apri file'),
                    onPressed: () => _openFile(context, ref),
                  ),
                  if (fileName.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(fileName, overflow: TextOverflow.ellipsis),
                        subtitle: const Text('File caricato'),
                        trailing: FilledButton.tonalIcon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Riproduci'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PlayerScreen()),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (recentFiles.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Aperti di recente',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...recentFiles.take(10).map((file) {
                      final path = file['path']!;
                      final name = file['name']!;
                      final lastPos = lastPositions[path] ?? 0;
                      final hasBm = bookmarks.containsKey(path) && bookmarks[path]! >= 0;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            hasBm ? Icons.bookmark : Icons.description,
                            size: 20,
                          ),
                          title: Text(name, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            lastPos > 0
                                ? 'Riprendi da parola $lastPos'
                                : 'Nuovo',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: FilledButton.tonalIcon(
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(lastPos > 0 ? 'Continua' : 'Apri'),
                            onPressed: () {
                              ref.read(playerProvider.notifier).loadFile(
                                path,
                                name,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PlayerScreen()),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    final service = ref.read(fileServiceProvider);

    final ok = await service.requestStoragePermission();
    if (!ok) {
      if (context.mounted) {
        final denied = await _showPermissionDeniedDialog(context);
        if (denied) {
          await service.openSystemSettings();
        }
      }
      return;
    }

    final file = await service.pickFile();
    if (file == null) return;

    if (context.mounted) {
      try {
        await ref.read(playerProvider.notifier).loadFile(
              file.path!,
              file.name,
            );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlayerScreen()),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e')),
          );
        }
      }
    }
  }

  Future<bool> _showPermissionDeniedDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permesso negato'),
            content: const Text(
              'CWReader ha bisogno dell\'accesso ai file per leggere EPUB e TXT. '
              'Vuoi aprire le impostazioni per concedere il permesso?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Apri impostazioni'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
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
            onPressed: () => _goToPage(kPageSettings),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('ICONA.png', width: 96, height: 96),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (fileName.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.description, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      fileName,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton.tonalIcon(
                                    icon: const Icon(Icons.play_arrow),
                                    label: const Text('Riproduci'),
                                    onPressed: () => _goToPage(kPagePlayer),
                                  ),
                                ],
                              ),
                            ],
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
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...recentFiles.take(10).map((file) {
                        final path = file['path']!;
                        final name = file['name']!;
                        final lastPos = lastPositions[path] ?? 0;
                        final hasBm =
                            bookmarks.containsKey(path) &&
                            bookmarks[path]! >= 0;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      hasBm
                                          ? Icons.bookmark
                                          : Icons.description,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyLarge,
                                          ),
                                          Text(
                                            lastPos > 0
                                                ? 'Riprendi da parola $lastPos'
                                                : 'Nuovo',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    FilledButton.tonalIcon(
                                      icon: const Icon(
                                        Icons.play_arrow,
                                        size: 18,
                                      ),
                                      label: Text(
                                        lastPos > 0 ? 'Continua' : 'Apri',
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(playerProvider.notifier)
                                            .loadFile(path, name);
                                        _goToPage(kPagePlayer);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      tooltip: 'Rimuovi',
                                      onPressed: () async {
                                        await removeRecentFile(path);
                                        ref.invalidate(recentFilesProvider);
                                        ref.invalidate(lastPositionsProvider);
                                        ref.invalidate(bookmarksProvider);
                                      },
                                    ),
                                  ],
                                ),
                              ],
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
      ),
    );
  }

  void _goToPage(int index) {
    ref.read(mainPageControllerProvider).animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
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

    final imported = await service.importBook(file);

    if (context.mounted) {
      try {
        await ref.read(playerProvider.notifier).loadFile(
              imported.path!,
              imported.name,
            );
        _goToPage(kPagePlayer);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Errore: $e')));
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

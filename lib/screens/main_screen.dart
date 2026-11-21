import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_providers.dart';
import '../services/update_checker.dart';
import 'home_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  static bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    if (!_updateChecked) {
      _updateChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
    }
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateChecker.checkForUpdate();
    if (info == null || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuova versione disponibile'),
        content: Text(
          'È disponibile CWReader ${info.version}. '
          'Vuoi scaricarla ora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Più tardi'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              launchUrl(
                Uri.parse(info.downloadUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Scarica'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(mainPageControllerProvider);
    return PageView(
      controller: controller,
      children: const [
        HomeScreen(),
        PlayerScreen(),
        SettingsScreen(),
      ],
    );
  }
}

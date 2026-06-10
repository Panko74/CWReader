import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/player_state.dart';
import '../models/substitution.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Audio'),
          _FrequencySlider(settings: settings, ref: ref),
          _WaveformSelector(settings: settings, ref: ref),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Velocità'),
          _WpmSlider(settings: settings, ref: ref),
          _FarnsworthSlider(settings: settings, ref: ref),
          _ExtraWordSpaceSlider(settings: settings, ref: ref),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Sostituzioni caratteri'),
          _SubstitutionList(settings: settings, ref: ref),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Info'),
          const _AboutSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _WpmSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _WpmSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Velocità: ${settings.wpm} WPM'),
            Slider(
              value: settings.wpm.toDouble(),
              min: 5,
              max: 60,
              divisions: 55,
              label: '${settings.wpm} WPM',
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).updateWpm(v.round()),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

double effectiveWpm(AppSettings s) {
  if (s.farnsworth <= 0) return s.wpm.toDouble();
  final effective = s.wpm / (1 + s.wpm * s.farnsworth / 15000.0);
  return effective.clamp(1.0, s.wpm.toDouble());
}

class _FarnsworthSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _FarnsworthSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final fw = settings.farnsworth;
    final ew = effectiveWpm(settings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spaziatura Farnsworth'),
            if (fw > 0)
              Text(
                'Effettiva: ${ew.toStringAsFixed(1)} WPM',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Slider(
              value: fw.toDouble(),
              min: 0,
              max: 500,
              divisions: 50,
              label: fw > 0 ? '${ew.toStringAsFixed(1)} WPM' : 'Off',
              onChanged: (v) => ref
                  .read(appSettingsProvider.notifier)
                  .updateFarnsworth(v.round()),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtraWordSpaceSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _ExtraWordSpaceSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final mult = settings.extraWordSpace;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spazio extra parole: ${mult.toStringAsFixed(1)}x'),
            Slider(
              value: mult,
              min: 1.0,
              max: 5.0,
              divisions: 16,
              label: '${mult.toStringAsFixed(1)}x',
              onChanged: (v) => ref
                  .read(appSettingsProvider.notifier)
                  .updateExtraWordSpace(v),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequencySlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _FrequencySlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tono: ${settings.frequency} Hz'),
            Slider(
              value: settings.frequency.toDouble(),
              min: 400,
              max: 900,
              divisions: 50,
              label: '${settings.frequency} Hz',
              onChanged: (v) => ref
                  .read(appSettingsProvider.notifier)
                  .updateFrequency(v.round()),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformSelector extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _WaveformSelector({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Forma d\'onda'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Waveform.values.map((wf) {
                final selected = settings.waveform == wf;
                return ChoiceChip(
                  label: Text(_waveformLabel(wf)),
                  selected: selected,
                  onSelected: (_) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .updateWaveform(wf);
                    ref.read(playerProvider.notifier).requestRegen();
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _waveformLabel(Waveform wf) {
    switch (wf) {
      case Waveform.sine:
        return 'Sinusoide';
      case Waveform.square:
        return 'Quadra';
      case Waveform.triangle:
        return 'Triangolare';
      case Waveform.sawtooth:
        return 'Dente di sega';
    }
  }
}

class _SubstitutionList extends ConsumerWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _SubstitutionList({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = settings.substitutions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (int i = 0; i < subs.length; i++)
              _SubstitutionTile(
                index: i,
                sub: subs[i],
                ref: ref,
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi sostituzione'),
              onPressed: () => _addSubstitution(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _addSubstitution(BuildContext context, WidgetRef ref) {
    final fromCtrl = TextEditingController();
    final toCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuova sostituzione'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromCtrl,
              decoration: const InputDecoration(labelText: 'Da'),
            ),
            TextField(
              controller: toCtrl,
              decoration: const InputDecoration(labelText: 'A'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              if (fromCtrl.text.isNotEmpty) {
                ref.read(appSettingsProvider.notifier).addSubstitution(
                      Substitution(
                        from: fromCtrl.text,
                        to: toCtrl.text,
                      ),
                    );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('CWReader',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text('v1.1.0',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('Sviluppato da IW5DUA',
                style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SubstitutionTile extends StatelessWidget {
  final int index;
  final Substitution sub;
  final WidgetRef ref;
  const _SubstitutionTile({
    required this.index,
    required this.sub,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: IconButton(
        icon: Icon(
          sub.enabled ? Icons.check_box : Icons.check_box_outline_blank,
        ),
        onPressed: () =>
            ref.read(appSettingsProvider.notifier).toggleSubstitution(index),
      ),
      title: Text('${sub.from}  →  ${sub.to}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () =>
            ref.read(appSettingsProvider.notifier).removeSubstitution(index),
      ),
    );
  }
}

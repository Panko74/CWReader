import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
          _EnvelopeSlider(settings: settings, ref: ref),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Velocità'),
          _WpmSlider(settings: settings, ref: ref),
          _FarnsworthSlider(settings: settings, ref: ref),
          _ExtraWordSpaceSlider(settings: settings, ref: ref),
          const SizedBox(height: 16),
          _SectionHeader(title: 'Effetti realismo'),
          _QsbSlider(settings: settings, ref: ref),
          _QsbPeriodSlider(settings: settings, ref: ref),
          _BandNoiseSlider(settings: settings, ref: ref),
          _QrnSlider(settings: settings, ref: ref),
          _FistSelector(settings: settings, ref: ref),
          _FistAmountSlider(settings: settings, ref: ref),
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

class _EnvelopeSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _EnvelopeSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final ms = settings.envelopeMs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ms > 0 ? 'Attacco: $ms ms' : 'Attacco: spento',
            ),
            Slider(
              value: ms.toDouble(),
              min: 0,
              max: 50,
              divisions: 10,
              label: ms > 0 ? '$ms ms' : 'Off',
              onChanged: (v) => ref
                  .read(appSettingsProvider.notifier)
                  .updateEnvelope(v.round()),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QsbSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _QsbSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QSB (fading): ${(settings.qsb * 100).round()}%'),
            Slider(
              value: settings.qsb,
              min: 0,
              max: 1.0,
              divisions: 20,
              label: '${(settings.qsb * 100).round()}%',
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).updateQsb(v),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QsbPeriodSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _QsbPeriodSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final s = settings.qsbPeriod;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Periodo QSB: ${s.toStringAsFixed(0)} s'),
            Slider(
              value: s,
              min: 10,
              max: 35,
              divisions: 25,
              label: '${s.toStringAsFixed(0)} s',
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).updateQsbPeriod(v),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandNoiseSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _BandNoiseSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rumore di banda: ${(settings.bandNoise * 100).round()}%'),
            Slider(
              value: settings.bandNoise,
              min: 0,
              max: 1.0,
              divisions: 20,
              label: '${(settings.bandNoise * 100).round()}%',
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).updateBandNoise(v),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrnSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _QrnSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QRN (static): ${(settings.qrn * 100).round()}%'),
            Slider(
              value: settings.qrn,
              min: 0,
              max: 1.0,
              divisions: 20,
              label: '${(settings.qrn * 100).round()}%',
              onChanged: (v) =>
                  ref.read(appSettingsProvider.notifier).updateQrn(v),
              onChangeEnd: (_) =>
                  ref.read(playerProvider.notifier).requestRegen(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FistSelector extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _FistSelector({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tipo di tasto (fist)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: FistType.values.map((ft) {
                final selected = settings.fistType == ft;
                return ChoiceChip(
                  label: Text(_fistLabel(ft)),
                  selected: selected,
                  onSelected: (_) {
                    ref
                        .read(appSettingsProvider.notifier)
                        .updateFistType(ft);
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

  String _fistLabel(FistType ft) {
    switch (ft) {
      case FistType.off:
        return 'Disattivato';
      case FistType.bug:
        return 'Bug';
      case FistType.straight:
        return 'Verticale';
      case FistType.paddle:
        return 'Paddle';
      case FistType.sideswiper:
        return 'Sideswiper';
    }
  }
}

class _FistAmountSlider extends StatelessWidget {
  final AppSettings settings;
  final WidgetRef ref;
  const _FistAmountSlider({required this.settings, required this.ref});

  @override
  Widget build(BuildContext context) {
    final enabled = settings.fistType != FistType.off;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quantità fist: ${(settings.fistAmount * 100).round()}%',
              style: TextStyle(
                color: enabled ? null : Theme.of(context).disabledColor,
              ),
            ),
            Slider(
              value: settings.fistAmount,
              min: 0,
              max: 1.0,
              divisions: 20,
              label: '${(settings.fistAmount * 100).round()}%',
              onChanged: enabled
                  ? (v) => ref
                      .read(appSettingsProvider.notifier)
                      .updateFistAmount(v)
                  : null,
              onChangeEnd: enabled
                  ? (_) => ref.read(playerProvider.notifier).requestRegen()
                  : null,
            ),
          ],
        ),
      ),
    );
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
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Aggiungi sostituzione',
                  style: TextStyle(fontSize: 16)),
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

class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = 'v${info.version}');
    }
  }

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
            Text(_version,
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
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: IconButton(
        icon: Icon(
          sub.enabled ? Icons.check_box : Icons.check_box_outline_blank,
          size: 28,
        ),
        onPressed: () =>
            ref.read(appSettingsProvider.notifier).toggleSubstitution(index),
      ),
      title: Text('${sub.from}  →  ${sub.to}',
          style: const TextStyle(fontSize: 18)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 24),
        onPressed: () =>
            ref.read(appSettingsProvider.notifier).removeSubstitution(index),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../settings/detection_settings.dart';
import '../settings/detection_settings_store.dart';

/// Tunes [DetectionSettings], persisted via [DetectionSettingsStore]. Takes
/// effect on the next session — a running recording isn't reconfigured live.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  DetectionSettings _settings = DetectionSettings.defaults;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await DetectionSettingsStore.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  void _apply(DetectionSettings settings) {
    setState(() => _settings = settings);
    DetectionSettingsStore.save(settings);
  }

  Future<void> _reset() async {
    await DetectionSettingsStore.reset();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to defaults',
            onPressed: _loading ? null : _reset,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Changes apply the next time you tap Start — a running session isn\'t reconfigured live.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                _SettingSlider(
                  label: 'Amplitude threshold',
                  valueLabel: '${_settings.thresholdDb.round()} dB',
                  value: _settings.thresholdDb,
                  min: -60,
                  max: -10,
                  divisions: 50,
                  onChanged: (v) => _apply(_settings.copyWith(thresholdDb: v)),
                ),
                _SettingSlider(
                  label: 'Sustained duration before a clip opens',
                  valueLabel: '${_settings.minSustained.inMilliseconds} ms',
                  value: _settings.minSustained.inMilliseconds.toDouble(),
                  min: 100,
                  max: 2000,
                  divisions: 38,
                  onChanged: (v) => _apply(_settings.copyWith(minSustained: Duration(milliseconds: v.round()))),
                ),
                _SettingSlider(
                  label: 'Hangover before a clip closes',
                  valueLabel: '${_settings.hangover.inMilliseconds} ms',
                  value: _settings.hangover.inMilliseconds.toDouble(),
                  min: 200,
                  max: 5000,
                  divisions: 48,
                  onChanged: (v) => _apply(_settings.copyWith(hangover: Duration(milliseconds: v.round()))),
                ),
                _SettingSlider(
                  label: 'Fall-asleep grace period',
                  valueLabel: _settings.fallAsleepGracePeriod == Duration.zero
                      ? 'Off'
                      : '${_settings.fallAsleepGracePeriod.inMinutes} min',
                  value: _settings.fallAsleepGracePeriod.inMinutes.toDouble(),
                  min: 0,
                  max: 60,
                  divisions: 60,
                  onChanged: (v) => _apply(_settings.copyWith(fallAsleepGracePeriod: Duration(minutes: v.round()))),
                ),
              ],
            ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(valueLabel, style: Theme.of(context).textTheme.bodySmall)],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

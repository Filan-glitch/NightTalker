import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'detection_settings.dart';

/// Persists [DetectionSettings] via `flutter_foreground_task`'s storage
/// (plain `SharedPreferences` under the hood) — already the mechanism data
/// crosses the UI/service isolate boundary with, so no new dependency is
/// needed and both isolates read the same values without extra plumbing.
/// `saveData` only supports int/double/String/bool, so each field gets its
/// own primitive key rather than one serialized blob.
abstract final class DetectionSettingsStore {
  static const _thresholdDbKey = 'detection.thresholdDb';
  static const _minSustainedMsKey = 'detection.minSustainedMs';
  static const _hangoverMsKey = 'detection.hangoverMs';
  static const _gracePeriodMinutesKey = 'detection.gracePeriodMinutes';

  /// Loads persisted settings, falling back to [DetectionSettings.defaults]
  /// field-by-field for anything never saved, then clamps the result.
  static Future<DetectionSettings> load() async {
    final thresholdDb = await FlutterForegroundTask.getData<double>(key: _thresholdDbKey);
    final minSustainedMs = await FlutterForegroundTask.getData<int>(key: _minSustainedMsKey);
    final hangoverMs = await FlutterForegroundTask.getData<int>(key: _hangoverMsKey);
    final gracePeriodMinutes = await FlutterForegroundTask.getData<int>(key: _gracePeriodMinutesKey);

    return DetectionSettings(
      thresholdDb: thresholdDb ?? DetectionSettings.defaults.thresholdDb,
      minSustained: minSustainedMs != null
          ? Duration(milliseconds: minSustainedMs)
          : DetectionSettings.defaults.minSustained,
      hangover: hangoverMs != null ? Duration(milliseconds: hangoverMs) : DetectionSettings.defaults.hangover,
      fallAsleepGracePeriod: gracePeriodMinutes != null
          ? Duration(minutes: gracePeriodMinutes)
          : DetectionSettings.defaults.fallAsleepGracePeriod,
    ).clamp();
  }

  static Future<void> save(DetectionSettings settings) async {
    final clamped = settings.clamp();
    await FlutterForegroundTask.saveData(key: _thresholdDbKey, value: clamped.thresholdDb);
    await FlutterForegroundTask.saveData(key: _minSustainedMsKey, value: clamped.minSustained.inMilliseconds);
    await FlutterForegroundTask.saveData(key: _hangoverMsKey, value: clamped.hangover.inMilliseconds);
    await FlutterForegroundTask.saveData(
      key: _gracePeriodMinutesKey,
      value: clamped.fallAsleepGracePeriod.inMinutes,
    );
  }

  static Future<void> reset() async {
    await FlutterForegroundTask.removeData(key: _thresholdDbKey);
    await FlutterForegroundTask.removeData(key: _minSustainedMsKey);
    await FlutterForegroundTask.removeData(key: _hangoverMsKey);
    await FlutterForegroundTask.removeData(key: _gracePeriodMinutesKey);
  }
}

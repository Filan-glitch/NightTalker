import '../core/constants.dart';

/// User-tunable overrides for [DetectionConstants]. Persisted via
/// `DetectionSettingsStore`; loaded by [ClipSegmenter] when a session starts.
class DetectionSettings {
  const DetectionSettings({
    required this.thresholdDb,
    required this.minSustained,
    required this.hangover,
    required this.fallAsleepGracePeriod,
  });

  static const defaults = DetectionSettings(
    thresholdDb: DetectionConstants.amplitudeThresholdDb,
    minSustained: DetectionConstants.minSustainedDuration,
    hangover: DetectionConstants.silenceHangover,
    fallAsleepGracePeriod: DetectionConstants.fallAsleepGracePeriod,
  );

  /// dBFS threshold sample must reach to count as "loud".
  final double thresholdDb;

  /// How long amplitude must stay above [thresholdDb] before a clip opens.
  final Duration minSustained;

  /// How long a clip stays open after amplitude drops back below threshold.
  final Duration hangover;

  /// How long after a session starts detection is ignored entirely.
  final Duration fallAsleepGracePeriod;

  static const _thresholdDbRange = (min: -60.0, max: -10.0);
  static const _minSustainedRange = (min: Duration(milliseconds: 100), max: Duration(milliseconds: 2000));
  static const _hangoverRange = (min: Duration(milliseconds: 200), max: Duration(milliseconds: 5000));
  static const _gracePeriodRange = (min: Duration.zero, max: Duration(minutes: 60));

  DetectionSettings copyWith({
    double? thresholdDb,
    Duration? minSustained,
    Duration? hangover,
    Duration? fallAsleepGracePeriod,
  }) => DetectionSettings(
    thresholdDb: thresholdDb ?? this.thresholdDb,
    minSustained: minSustained ?? this.minSustained,
    hangover: hangover ?? this.hangover,
    fallAsleepGracePeriod: fallAsleepGracePeriod ?? this.fallAsleepGracePeriod,
  );

  /// Clamps every field into its valid range — guards against corrupted or
  /// stale persisted values (e.g. from a version with different bounds).
  DetectionSettings clamp() {
    return DetectionSettings(
      thresholdDb: thresholdDb.clamp(_thresholdDbRange.min, _thresholdDbRange.max),
      minSustained: _clampDuration(minSustained, _minSustainedRange.min, _minSustainedRange.max),
      hangover: _clampDuration(hangover, _hangoverRange.min, _hangoverRange.max),
      fallAsleepGracePeriod: _clampDuration(fallAsleepGracePeriod, _gracePeriodRange.min, _gracePeriodRange.max),
    );
  }

  static Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is DetectionSettings &&
      other.thresholdDb == thresholdDb &&
      other.minSustained == minSustained &&
      other.hangover == hangover &&
      other.fallAsleepGracePeriod == fallAsleepGracePeriod;

  @override
  int get hashCode => Object.hash(thresholdDb, minSustained, hangover, fallAsleepGracePeriod);
}

/// Tunable detection/session constants.
///
/// This file is the single place amplitude-detection and session-safety
/// thresholds live. These are the defaults `DetectionSettings` starts from —
/// the settings screen (build step 7) lets a user override them, persisted
/// via `flutter_foreground_task`'s storage. The values below are starting
/// points that will need tuning against real overnight recordings (bedroom
/// noise floor, phone mic sensitivity, etc.).
library;

/// Thresholds driving [AmplitudeThresholdDetector] and [ClipSegmenter].
abstract final class DetectionConstants {
  /// Amplitude (dBFS, from `record`'s `onAmplitudeChanged` stream) above
  /// which a sample is considered "loud enough to possibly be talking".
  static const double amplitudeThresholdDb = -30.0;

  /// Sound must stay above [amplitudeThresholdDb] for at least this long,
  /// continuously, before a clip is opened. Filters out single clicks/pops.
  static const Duration minSustainedDuration = Duration(milliseconds: 400);

  /// After sound drops back below threshold, keep the clip open for this
  /// long before closing it — merges short pauses within one utterance
  /// into a single clip instead of splitting it into fragments.
  static const Duration silenceHangover = Duration(milliseconds: 1500);

  /// How often the amplitude stream is polled.
  static const Duration amplitudePollInterval = Duration(milliseconds: 200);

  /// How long after a session starts [ClipSegmenter] ignores amplitude
  /// entirely — no detection, so no clip can open — giving the user time to
  /// settle in and fall asleep without the sounds of doing so being
  /// recorded. Zero disables it.
  static const Duration fallAsleepGracePeriod = Duration(minutes: 15);
}

/// Session-level safety constants.
abstract final class SessionConstants {
  /// Hard auto-stop cap, independent of manual Stop, guarding against a
  /// forgotten session draining battery/storage all day.
  static const Duration safetyAutoStopCap = Duration(hours: 11);
}

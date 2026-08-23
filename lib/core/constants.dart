/// Tunable detection/session constants.
///
/// This file is the single place amplitude-detection and session-safety
/// thresholds live. It is the first candidate for a future Settings screen —
/// none of these are user-configurable in the MVP, and the defaults below
/// are starting points that will need tuning against real overnight
/// recordings (bedroom noise floor, phone mic sensitivity, etc.).
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
}

/// Session-level safety constants.
abstract final class SessionConstants {
  /// Hard auto-stop cap, independent of manual Stop, guarding against a
  /// forgotten session draining battery/storage all day.
  static const Duration safetyAutoStopCap = Duration(hours: 11);
}

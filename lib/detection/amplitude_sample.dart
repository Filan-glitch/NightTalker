/// One amplitude reading from `record`'s `onAmplitudeChanged` stream, paired
/// with when it was taken. [AmplitudeThresholdDetector] consumes these.
class AmplitudeSample {
  const AmplitudeSample(this.db, this.at);

  /// Amplitude in dBFS.
  final double db;

  final DateTime at;
}

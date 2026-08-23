enum SegmentEventType { started, ended }

/// Emitted by [AmplitudeThresholdDetector] when a clip should open or close.
///
/// [at] is the timestamp of the sample that triggered the transition (the
/// sample completing [DetectionConstants.minSustainedDuration] for
/// [SegmentEventType.started], or completing
/// [DetectionConstants.silenceHangover] for [SegmentEventType.ended]).
class SegmentEvent {
  const SegmentEvent(this.type, this.at);

  final SegmentEventType type;
  final DateTime at;
}

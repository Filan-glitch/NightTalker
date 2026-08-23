import 'amplitude_sample.dart';
import 'segment_event.dart';

/// Pure state machine turning a stream of timestamped amplitude samples into
/// clip open/close events. No I/O, no timers — driven entirely by the
/// timestamps on the samples it's fed, so it's deterministic to test.
///
/// A clip opens once amplitude stays at or above [thresholdDb] continuously
/// for [minSustained], and closes once amplitude stays below [thresholdDb]
/// continuously for [hangover] (a brief dip back above threshold during that
/// hangover window cancels the close, keeping the clip open).
class AmplitudeThresholdDetector {
  AmplitudeThresholdDetector({
    required this.thresholdDb,
    required this.minSustained,
    required this.hangover,
  });

  final double thresholdDb;
  final Duration minSustained;
  final Duration hangover;

  bool _open = false;
  DateTime? _loudSince;
  DateTime? _quietSince;

  /// Feeds one sample in. Returns the event triggered by it, if any.
  SegmentEvent? addSample(AmplitudeSample sample) {
    final loud = sample.db >= thresholdDb;

    if (!_open) {
      if (!loud) {
        _loudSince = null;
        return null;
      }
      _loudSince ??= sample.at;
      if (sample.at.difference(_loudSince!) >= minSustained) {
        _open = true;
        _loudSince = null;
        return SegmentEvent(SegmentEventType.started, sample.at);
      }
      return null;
    }

    if (loud) {
      _quietSince = null;
      return null;
    }
    _quietSince ??= sample.at;
    if (sample.at.difference(_quietSince!) >= hangover) {
      _open = false;
      _quietSince = null;
      return SegmentEvent(SegmentEventType.ended, sample.at);
    }
    return null;
  }
}

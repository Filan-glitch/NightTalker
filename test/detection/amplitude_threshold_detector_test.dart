import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/detection/amplitude_sample.dart';
import 'package:nighttalker/detection/amplitude_threshold_detector.dart';
import 'package:nighttalker/detection/segment_event.dart';

void main() {
  final start = DateTime(2026);

  test('opens a segment once loud sustained for the full minSustained duration', () {
    final detector = AmplitudeThresholdDetector(
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 400),
      hangover: const Duration(milliseconds: 1500),
    );

    // Below the full duration: no event yet.
    expect(
      detector.addSample(AmplitudeSample(-10, start)),
      isNull,
    );
    expect(
      detector.addSample(AmplitudeSample(-10, start.add(const Duration(milliseconds: 200)))),
      isNull,
    );

    // Reaches the full sustained duration: segment opens.
    final event = detector.addSample(
      AmplitudeSample(-10, start.add(const Duration(milliseconds: 400))),
    );
    expect(event, isNotNull);
    expect(event!.type, SegmentEventType.started);
  });

  test('a quiet dip before minSustained resets the loud streak', () {
    final detector = AmplitudeThresholdDetector(
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 400),
      hangover: const Duration(milliseconds: 1500),
    );

    detector.addSample(AmplitudeSample(-10, start));
    // Dips below threshold before 400ms elapses: streak must reset.
    detector.addSample(AmplitudeSample(-40, start.add(const Duration(milliseconds: 200))));
    // Loud again, but only 300ms since the reset — must NOT have opened yet.
    final event = detector.addSample(
      AmplitudeSample(-10, start.add(const Duration(milliseconds: 500))),
    );

    expect(event, isNull);
  });

  test('closes an open segment once quiet sustained for the full hangover duration', () {
    final detector = AmplitudeThresholdDetector(
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 400),
      hangover: const Duration(milliseconds: 1500),
    );

    // Open the segment.
    detector.addSample(AmplitudeSample(-10, start));
    detector.addSample(AmplitudeSample(-10, start.add(const Duration(milliseconds: 400))));

    // Goes quiet. Before hangover elapses: no event yet.
    final quietStart = start.add(const Duration(milliseconds: 400));
    expect(
      detector.addSample(AmplitudeSample(-40, quietStart)),
      isNull,
    );
    expect(
      detector.addSample(AmplitudeSample(-40, quietStart.add(const Duration(milliseconds: 1000)))),
      isNull,
    );

    // Hangover fully elapsed: segment closes.
    final event = detector.addSample(
      AmplitudeSample(-40, quietStart.add(const Duration(milliseconds: 1500))),
    );
    expect(event, isNotNull);
    expect(event!.type, SegmentEventType.ended);
  });

  test('loud again during hangover cancels the close and keeps the segment open', () {
    final detector = AmplitudeThresholdDetector(
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 400),
      hangover: const Duration(milliseconds: 1500),
    );

    detector.addSample(AmplitudeSample(-10, start));
    detector.addSample(AmplitudeSample(-10, start.add(const Duration(milliseconds: 400))));

    // Short pause, then loud again well before hangover would elapse.
    var t = start.add(const Duration(milliseconds: 400));
    detector.addSample(AmplitudeSample(-40, t));
    t = t.add(const Duration(milliseconds: 800));
    expect(detector.addSample(AmplitudeSample(-10, t)), isNull); // still open, no "started" re-fire

    // Now go quiet again for the FULL hangover, measured from this point.
    // If the earlier pause had counted, the segment would have already
    // closed by t + 700ms; it must not have.
    t = t.add(const Duration(milliseconds: 700));
    expect(detector.addSample(AmplitudeSample(-40, t)), isNull);

    t = t.add(const Duration(milliseconds: 1500));
    final event = detector.addSample(AmplitudeSample(-40, t));
    expect(event, isNotNull);
    expect(event!.type, SegmentEventType.ended);
  });

  test('a sample exactly at thresholdDb counts as loud', () {
    final detector = AmplitudeThresholdDetector(
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 400),
      hangover: const Duration(milliseconds: 1500),
    );

    detector.addSample(AmplitudeSample(-30, start));
    final event = detector.addSample(
      AmplitudeSample(-30, start.add(const Duration(milliseconds: 400))),
    );

    expect(event, isNotNull);
    expect(event!.type, SegmentEventType.started);
  });

  test('reopening after a close requires a fresh full minSustained streak', () {
    final detector = AmplitudeThresholdDetector(
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 400),
      hangover: const Duration(milliseconds: 1500),
    );

    // Open, then close.
    detector.addSample(AmplitudeSample(-10, start));
    detector.addSample(AmplitudeSample(-10, start.add(const Duration(milliseconds: 400))));
    var t = start.add(const Duration(milliseconds: 400));
    detector.addSample(AmplitudeSample(-40, t));
    t = t.add(const Duration(milliseconds: 1500));
    final closeEvent = detector.addSample(AmplitudeSample(-40, t));
    expect(closeEvent!.type, SegmentEventType.ended);

    // Loud streak resumes here (t0). 300ms in — must not have reopened yet.
    final t0 = t;
    detector.addSample(AmplitudeSample(-10, t0));
    t = t0.add(const Duration(milliseconds: 300));
    final tooSoon = detector.addSample(AmplitudeSample(-10, t));
    expect(tooSoon, isNull);

    // Reaches a full fresh 400ms from t0: reopens.
    t = t0.add(const Duration(milliseconds: 400));
    final reopened = detector.addSample(AmplitudeSample(-10, t));
    expect(reopened, isNotNull);
    expect(reopened!.type, SegmentEventType.started);
  });
}

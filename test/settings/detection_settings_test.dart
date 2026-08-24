import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/settings/detection_settings.dart';

void main() {
  group('defaults', () {
    test('mirrors DetectionConstants', () {
      const defaults = DetectionSettings.defaults;

      expect(defaults.thresholdDb, -30.0);
      expect(defaults.minSustained, const Duration(milliseconds: 400));
      expect(defaults.hangover, const Duration(milliseconds: 1500));
      expect(defaults.fallAsleepGracePeriod, const Duration(minutes: 15));
    });
  });

  group('clamp', () {
    test('leaves values already within bounds unchanged', () {
      const settings = DetectionSettings(
        thresholdDb: -25,
        minSustained: Duration(milliseconds: 600),
        hangover: Duration(milliseconds: 2000),
        fallAsleepGracePeriod: Duration(minutes: 10),
      );

      expect(settings.clamp(), settings);
    });

    test('clamps thresholdDb to [-60, -10]', () {
      expect(
        const DetectionSettings(
          thresholdDb: -100,
          minSustained: Duration(milliseconds: 400),
          hangover: Duration(milliseconds: 1500),
          fallAsleepGracePeriod: Duration(minutes: 15),
        ).clamp().thresholdDb,
        -60,
      );
      expect(
        const DetectionSettings(
          thresholdDb: 0,
          minSustained: Duration(milliseconds: 400),
          hangover: Duration(milliseconds: 1500),
          fallAsleepGracePeriod: Duration(minutes: 15),
        ).clamp().thresholdDb,
        -10,
      );
    });

    test('clamps minSustained to [100ms, 2000ms]', () {
      expect(
        const DetectionSettings(
          thresholdDb: -30,
          minSustained: Duration(milliseconds: 10),
          hangover: Duration(milliseconds: 1500),
          fallAsleepGracePeriod: Duration(minutes: 15),
        ).clamp().minSustained,
        const Duration(milliseconds: 100),
      );
      expect(
        const DetectionSettings(
          thresholdDb: -30,
          minSustained: Duration(milliseconds: 5000),
          hangover: Duration(milliseconds: 1500),
          fallAsleepGracePeriod: Duration(minutes: 15),
        ).clamp().minSustained,
        const Duration(milliseconds: 2000),
      );
    });

    test('clamps hangover to [200ms, 5000ms]', () {
      expect(
        const DetectionSettings(
          thresholdDb: -30,
          minSustained: Duration(milliseconds: 400),
          hangover: Duration(milliseconds: 10),
          fallAsleepGracePeriod: Duration(minutes: 15),
        ).clamp().hangover,
        const Duration(milliseconds: 200),
      );
      expect(
        const DetectionSettings(
          thresholdDb: -30,
          minSustained: Duration(milliseconds: 400),
          hangover: Duration(milliseconds: 20000),
          fallAsleepGracePeriod: Duration(minutes: 15),
        ).clamp().hangover,
        const Duration(milliseconds: 5000),
      );
    });

    test('clamps fallAsleepGracePeriod to [0, 60min]', () {
      expect(
        const DetectionSettings(
          thresholdDb: -30,
          minSustained: Duration(milliseconds: 400),
          hangover: Duration(milliseconds: 1500),
          fallAsleepGracePeriod: Duration(minutes: -5),
        ).clamp().fallAsleepGracePeriod,
        Duration.zero,
      );
      expect(
        const DetectionSettings(
          thresholdDb: -30,
          minSustained: Duration(milliseconds: 400),
          hangover: Duration(milliseconds: 1500),
          fallAsleepGracePeriod: Duration(minutes: 120),
        ).clamp().fallAsleepGracePeriod,
        const Duration(minutes: 60),
      );
    });
  });
}

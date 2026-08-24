import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/detection/segment_event.dart';
import 'package:nighttalker/recording/task_message.dart';

void main() {
  group('SegmentEventMessage', () {
    test('round-trips through toMap/decodeTaskMessage', () {
      const message = SegmentEventMessage(SegmentEventType.started);

      final decoded = decodeTaskMessage(message.toMap());

      expect(decoded, isA<SegmentEventMessage>());
      expect((decoded as SegmentEventMessage).type, SegmentEventType.started);
    });
  });

  group('ClipSavedMessage', () {
    test('round-trips through toMap/decodeTaskMessage', () {
      const message = ClipSavedMessage('/clips/clip_1.wav');

      final decoded = decodeTaskMessage(message.toMap());

      expect(decoded, isA<ClipSavedMessage>());
      expect((decoded as ClipSavedMessage).path, '/clips/clip_1.wav');
    });
  });

  group('AutoStoppedMessage', () {
    test('round-trips through toMap/decodeTaskMessage', () {
      const message = AutoStoppedMessage();

      final decoded = decodeTaskMessage(message.toMap());

      expect(decoded, isA<AutoStoppedMessage>());
    });
  });

  group('decodeTaskMessage', () {
    test('returns null for data that is not a recognized message', () {
      expect(decodeTaskMessage('not a map'), isNull);
      expect(decodeTaskMessage(<String, Object?>{'kind': 'unknown'}), isNull);
      expect(decodeTaskMessage(<String, Object?>{'kind': 'clipSaved', 'path': 123}), isNull);
    });
  });
}

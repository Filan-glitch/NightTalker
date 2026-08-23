import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../detection/segment_event.dart';
import 'clip_segmenter.dart';
import 'task_message.dart';

/// Runs inside `flutter_foreground_task`'s service isolate — a separate
/// Flutter engine bound to the Android `Service` component, independent of
/// `MainActivity`. [ClipSegmenter] lives here rather than in the UI isolate
/// so an overnight session keeps recording even if Android reclaims the
/// activity's engine while the phone is asleep.
///
/// [onSegmentEvent]/[onClipSaved] are forwarded to the UI isolate as plain
/// maps (see [TaskMessage]) via [sendData], and mirrored into the
/// persistent notification's text via [updateNotificationText] so the
/// notification itself is informative even if the user doesn't reopen the
/// app.
class RecordingTaskHandler extends TaskHandler {
  RecordingTaskHandler({
    ClipSegmenter? segmenter,
    void Function(Object data)? sendData,
    void Function(String text)? updateNotificationText,
  }) : _segmenter = segmenter ?? ClipSegmenter(),
       _sendData = sendData ?? FlutterForegroundTask.sendDataToMain,
       _updateNotificationText = updateNotificationText ?? _defaultUpdateNotificationText;

  final ClipSegmenter _segmenter;
  final void Function(Object data) _sendData;
  final void Function(String text) _updateNotificationText;

  StreamSubscription<SegmentEvent>? _segmentEventSub;
  StreamSubscription<String>? _clipSavedSub;
  bool _recording = false;
  int _clipCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _segmentEventSub = _segmenter.onSegmentEvent.listen((event) {
      _recording = event.type == SegmentEventType.started;
      _sendData(SegmentEventMessage(event.type).toMap());
      _updateNotificationText(_statusText());
    });
    _clipSavedSub = _segmenter.onClipSaved.listen((path) {
      _clipCount++;
      _sendData(ClipSavedMessage(path).toMap());
      _updateNotificationText(_statusText());
    });

    await _segmenter.start();
    _updateNotificationText(_statusText());
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _segmenter.stop(); // finalizes a clip still open rather than discarding it
    await _segmentEventSub?.cancel();
    await _clipSavedSub?.cancel();
    await _segmenter.dispose();
  }

  String _statusText() {
    final state = _recording ? 'Recording…' : 'Listening…';
    final clips = '$_clipCount clip${_clipCount == 1 ? '' : 's'} saved';
    return '$state · $clips';
  }

  static void _defaultUpdateNotificationText(String text) {
    unawaited(FlutterForegroundTask.updateService(notificationText: text));
  }
}

/// The callback function must be a top-level or static function — the
/// plugin looks it up by name to run it in the service's isolate.
@pragma('vm:entry-point')
void startRecordingCallback() {
  FlutterForegroundTask.setTaskHandler(RecordingTaskHandler());
}

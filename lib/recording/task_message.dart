import '../detection/segment_event.dart';

/// Everything [RecordingTaskHandler] sends from the foreground service's
/// isolate back to the UI isolate via `FlutterForegroundTask.sendDataToMain`.
///
/// The plugin's isolate bridge only ferries plain data (maps, lists,
/// primitives) — not arbitrary Dart objects — so each message knows how to
/// flatten itself to a [Map] via [toMap]; [decodeTaskMessage] is the
/// receiving side's inverse.
sealed class TaskMessage {
  const TaskMessage();

  Map<String, Object?> toMap();
}

/// Mirrors a [SegmentEvent] fired by the detector inside the service.
class SegmentEventMessage extends TaskMessage {
  const SegmentEventMessage(this.type);

  final SegmentEventType type;

  @override
  Map<String, Object?> toMap() => {'kind': 'segmentEvent', 'eventType': type.name};
}

/// A clip finished writing to disk at [path].
class ClipSavedMessage extends TaskMessage {
  const ClipSavedMessage(this.path);

  final String path;

  @override
  Map<String, Object?> toMap() => {'kind': 'clipSaved', 'path': path};
}

/// The service is about to stop itself after [SessionConstants.safetyAutoStopCap]
/// — sent right before `stopService()` so the UI can reflect it immediately
/// rather than waiting to notice the service died.
class AutoStoppedMessage extends TaskMessage {
  const AutoStoppedMessage();

  @override
  Map<String, Object?> toMap() => {'kind': 'autoStopped'};
}

/// Parses data received via `FlutterForegroundTask.sendDataToMain` /
/// `addTaskDataCallback` back into a [TaskMessage]. Returns null for
/// anything unrecognized rather than throwing — the sender and receiver run
/// in different isolates, so there's no compile-time guarantee they agree.
TaskMessage? decodeTaskMessage(Object? raw) {
  if (raw is! Map) return null;

  switch (raw['kind']) {
    case 'segmentEvent':
      final eventType = raw['eventType'];
      for (final type in SegmentEventType.values) {
        if (type.name == eventType) return SegmentEventMessage(type);
      }
      return null;
    case 'clipSaved':
      final path = raw['path'];
      return path is String ? ClipSavedMessage(path) : null;
    case 'autoStopped':
      return const AutoStoppedMessage();
    default:
      return null;
  }
}

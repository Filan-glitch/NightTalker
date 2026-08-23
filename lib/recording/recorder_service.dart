import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../core/constants.dart';

/// Thin wrapper around `record`'s [AudioRecorder]: owns the clips directory,
/// filename generation, and start/stop lifecycle for a single AAC (.m4a)
/// file. Deliberately has no detection/segmentation logic — that's layered
/// on top by [ClipSegmenter] in a later build step, so this class stays a
/// pure "file I/O + mic session" concern.
///
/// Build-step 1 scope: one continuous recording per Start/Stop, no
/// background service, no clip segmentation yet.
class RecorderService {
  RecorderService({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// Checks (and, per `record`'s default behavior, requests) microphone
  /// permission. Returns whether recording is allowed to proceed.
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Directory> _clipsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/clips');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Starts recording a new AAC (.m4a) file and returns its path.
  Future<String> start() async {
    final dir = await _clipsDirectory();
    final path = '${dir.path}/session_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    return path;
  }

  /// Amplitude samples (dBFS) while recording, at [DetectionConstants.amplitudePollInterval].
  Stream<double> get amplitudeStream => _recorder
      .onAmplitudeChanged(DetectionConstants.amplitudePollInterval)
      .map((amplitude) => amplitude.current);

  /// Stops the current recording, returning the file path (or null if
  /// nothing was recording).
  Future<String?> stop() => _recorder.stop();

  Future<void> dispose() => _recorder.dispose();
}

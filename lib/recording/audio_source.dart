import 'dart:typed_data';

import 'package:record/record.dart';

/// Everything [ClipSegmenter] needs from the microphone: a continuous raw
/// PCM byte stream plus the amplitude readings the `record` plugin computes
/// alongside it. Narrow seam so tests can supply a fake instead of touching
/// the real plugin.
abstract class AudioSource {
  /// Checks (and, per `record`'s default behavior, requests) microphone
  /// permission. Returns whether recording is allowed to proceed.
  Future<bool> hasPermission();

  /// Amplitude (dBFS) readings taken while streaming, at whatever cadence
  /// the implementation polls at.
  Stream<double> get amplitudeStream;

  /// Starts a continuous raw-PCM recording session and returns its byte
  /// stream. Must be called before [amplitudeStream] produces anything.
  Future<Stream<Uint8List>> startStream();

  /// Ends the session.
  Future<void> stop();
}

/// [AudioSource] backed by the real `record` plugin. Thin adapter with no
/// logic of its own — exercised via manual device runs like [RecorderService]
/// was in build step 1, not unit tests.
class RecordAudioSource implements AudioSource {
  RecordAudioSource({
    required this.sampleRate,
    required this.numChannels,
    required this.amplitudePollInterval,
    AudioRecorder? recorder,
  }) : _recorder = recorder ?? AudioRecorder();

  final int sampleRate;
  final int numChannels;
  final Duration amplitudePollInterval;
  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Stream<double> get amplitudeStream =>
      _recorder.onAmplitudeChanged(amplitudePollInterval).map((amplitude) => amplitude.current);

  @override
  Future<Stream<Uint8List>> startStream() => _recorder.startStream(
    RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: sampleRate, numChannels: numChannels),
  );

  @override
  Future<void> stop() => _recorder.stop();
}

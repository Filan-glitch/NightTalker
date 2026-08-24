import 'dart:async';
import 'dart:io';

import '../core/constants.dart';
import '../detection/amplitude_sample.dart';
import '../detection/amplitude_threshold_detector.dart';
import '../detection/segment_event.dart';
import 'audio_source.dart';
import 'clips_directory.dart';
import 'pcm_ring_buffer.dart';
import 'wav_writer.dart';

/// Runs one continuous mic session for the whole Start/Stop window and cuts
/// it into per-utterance WAV clips: [AmplitudeThresholdDetector] decides
/// when a clip should open/close, [PcmRingBuffer] supplies the pre-roll so a
/// clip's audio doesn't start mid-word, and each clip is written out via
/// [WavWriter] as it closes.
///
/// One continuous [AudioSource] session backs the whole listening window —
/// `record`'s amplitude stream only reports while actively recording, so
/// there's no way to sample amplitude during a gap between clips.
class ClipSegmenter {
  ClipSegmenter({
    AudioSource? audioSource,
    DateTime Function()? clock,
    Future<Directory> Function()? clipsDirectory,
    double thresholdDb = DetectionConstants.amplitudeThresholdDb,
    Duration minSustained = DetectionConstants.minSustainedDuration,
    Duration hangover = DetectionConstants.silenceHangover,
    Duration amplitudePollInterval = DetectionConstants.amplitudePollInterval,
    this.gracePeriod = DetectionConstants.fallAsleepGracePeriod,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.bitsPerSample = 16,
  }) : _audioSource =
           audioSource ??
           RecordAudioSource(
             sampleRate: sampleRate,
             numChannels: numChannels,
             amplitudePollInterval: amplitudePollInterval,
           ),
       _clock = clock ?? DateTime.now,
       _clipsDirectory = clipsDirectory ?? resolveClipsDirectory,
       _detector = AmplitudeThresholdDetector(thresholdDb: thresholdDb, minSustained: minSustained, hangover: hangover),
       _ringBuffer = PcmRingBuffer(
         maxBytes: _bytesFor(duration: minSustained, sampleRate: sampleRate, numChannels: numChannels, bitsPerSample: bitsPerSample),
       );

  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;
  final Duration gracePeriod;

  final AudioSource _audioSource;
  final DateTime Function() _clock;
  final Future<Directory> Function() _clipsDirectory;
  final AmplitudeThresholdDetector _detector;
  final PcmRingBuffer _ringBuffer;

  final _clipSavedController = StreamController<String>.broadcast();
  final _segmentEventController = StreamController<SegmentEvent>.broadcast();

  StreamSubscription<void>? _pcmSub;
  StreamSubscription<void>? _ampSub;
  WavWriter? _openClip;
  DateTime? _sessionStartedAt;

  /// Emits the path of each clip as soon as it's written to disk.
  Stream<String> get onClipSaved => _clipSavedController.stream;

  /// Emits live as the detector opens/closes a segment — fires before the
  /// clip is actually saved, so UI can show "recording" the moment it
  /// starts rather than waiting for [onClipSaved].
  Stream<SegmentEvent> get onSegmentEvent => _segmentEventController.stream;

  /// Checks (and requests) microphone permission. Call before [start].
  Future<bool> hasPermission() => _audioSource.hasPermission();

  /// Starts the continuous listening session.
  Future<void> start() async {
    final pcmStream = await _audioSource.startStream();
    _sessionStartedAt = _clock();

    _pcmSub = pcmStream.listen((bytes) {
      _ringBuffer.add(bytes);
      _openClip?.addBytes(bytes);
    });

    _ampSub = _audioSource.amplitudeStream.listen((db) {
      final now = _clock();
      // Ignore amplitude entirely while still inside the grace period — no
      // sample reaches the detector, so no segment can open. The ring
      // buffer above keeps running regardless (it's the pre-roll, never
      // persisted unless a segment opens), so nothing here is discarded
      // audio — it's audio that's simply never evaluated.
      if (now.difference(_sessionStartedAt!) < gracePeriod) return;

      final event = _detector.addSample(AmplitudeSample(db, now));
      if (event == null) return;
      _segmentEventController.add(event);
      switch (event.type) {
        case SegmentEventType.started:
          _openClip = WavWriter(sampleRate: sampleRate, numChannels: numChannels, bitsPerSample: bitsPerSample)
            ..addBytes(_ringBuffer.snapshot());
        case SegmentEventType.ended:
          unawaited(_closeCurrentClip());
      }
    });
  }

  /// Ends the listening session, finalizing a clip still open rather than
  /// discarding it.
  Future<void> stop() async {
    await _audioSource.stop();
    await _ampSub?.cancel();
    await _pcmSub?.cancel();
    await _closeCurrentClip();
  }

  /// Releases resources. Call once the segmenter is no longer needed.
  Future<void> dispose() async {
    await _ampSub?.cancel();
    await _pcmSub?.cancel();
    await _clipSavedController.close();
    await _segmentEventController.close();
  }

  Future<void> _closeCurrentClip() async {
    final clip = _openClip;
    _openClip = null;
    if (clip == null) return;

    final dir = await _clipsDirectory();
    final path = '${dir.path}/clip_${_clock().millisecondsSinceEpoch}.wav';
    await clip.writeToFile(path);
    _clipSavedController.add(path);
  }

  static int _bytesFor({
    required Duration duration,
    required int sampleRate,
    required int numChannels,
    required int bitsPerSample,
  }) {
    final bytesPerSecond = sampleRate * numChannels * bitsPerSample ~/ 8;
    final bytes = (bytesPerSecond * duration.inMicroseconds) ~/ Duration.microsecondsPerSecond;
    return bytes < 1 ? 1 : bytes;
  }
}

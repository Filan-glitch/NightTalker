import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/detection/segment_event.dart';
import 'package:nighttalker/recording/audio_source.dart';
import 'package:nighttalker/recording/clip_segmenter.dart';

/// Test double for [AudioSource]: lets the test drive PCM and amplitude
/// events on its own timeline instead of a real microphone.
class FakeAudioSource implements AudioSource {
  final _pcmController = StreamController<Uint8List>.broadcast(sync: true);
  final _ampController = StreamController<double>.broadcast(sync: true);
  bool started = false;
  bool stopped = false;

  @override
  Stream<double> get amplitudeStream => _ampController.stream;

  @override
  Future<Stream<Uint8List>> startStream() async {
    started = true;
    return _pcmController.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  bool permissionGranted = true;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  void emitPcm(int byte) => _pcmController.add(Uint8List.fromList([byte]));
  void emitAmplitude(double db) => _ampController.add(db);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clip_segmenter_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('saves a clip containing pre-roll + in-segment + hangover PCM, excluding what came before/after', () async {
    final source = FakeAudioSource();
    var now = DateTime(2026);

    final segmenter = ClipSegmenter(
      audioSource: source,
      clock: () => now,
      clipsDirectory: () async => tempDir,
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 200),
      hangover: const Duration(milliseconds: 200),
      gracePeriod: Duration.zero,
      sampleRate: 10, // 10 bytes/sec at 8-bit mono => 1 byte per 100ms tick
      numChannels: 1,
      bitsPerSample: 8,
    );

    final savedPaths = <String>[];
    segmenter.onClipSaved.listen(savedPaths.add);

    await segmenter.start();
    expect(source.started, isTrue);

    Future<void> tick(int atMs, int pcmByte, double db) async {
      now = DateTime(2026).add(Duration(milliseconds: atMs));
      source.emitPcm(pcmByte);
      await pumpEventQueue();
      source.emitAmplitude(db);
      await pumpEventQueue();
    }

    await tick(0, 0xA0, -40); // quiet, before the pre-roll window
    await tick(100, 0xA1, -40); // quiet, before the pre-roll window
    await tick(200, 0xA2, -10); // loud streak begins (pre-roll: ring cap = 2 bytes)
    await tick(400, 0xA3, -10); // 200ms sustained: segment opens here
    await tick(600, 0xA4, -10); // still loud, mid-segment
    await tick(800, 0xA5, -40); // goes quiet, hangover starts
    await tick(1000, 0xA6, -40); // 200ms of quiet: hangover elapses, segment closes
    await tick(1200, 0xA7, -40); // after close: must not be included

    await segmenter.stop();
    expect(source.stopped, isTrue);

    expect(savedPaths, hasLength(1));
    final bytes = await File(savedPaths.first).readAsBytes();
    final pcm = bytes.sublist(44); // skip the WAV header

    expect(pcm, [0xA2, 0xA3, 0xA4, 0xA5, 0xA6]);
  });

  test('stop() finalizes a still-open clip instead of discarding it', () async {
    final source = FakeAudioSource();
    var now = DateTime(2026);

    final segmenter = ClipSegmenter(
      audioSource: source,
      clock: () => now,
      clipsDirectory: () async => tempDir,
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 200),
      hangover: const Duration(milliseconds: 200),
      gracePeriod: Duration.zero,
      sampleRate: 10,
      numChannels: 1,
      bitsPerSample: 8,
    );

    final savedPaths = <String>[];
    segmenter.onClipSaved.listen(savedPaths.add);

    await segmenter.start();

    Future<void> tick(int atMs, int pcmByte, double db) async {
      now = DateTime(2026).add(Duration(milliseconds: atMs));
      source.emitPcm(pcmByte);
      await pumpEventQueue();
      source.emitAmplitude(db);
      await pumpEventQueue();
    }

    await tick(0, 0xB0, -10);
    await tick(200, 0xB1, -10); // segment opens

    // Stop mid-segment, well before hangover would ever elapse.
    await segmenter.stop();
    await pumpEventQueue(); // let the broadcast StreamController deliver onClipSaved

    expect(savedPaths, hasLength(1));
    final bytes = await File(savedPaths.first).readAsBytes();
    expect(bytes.sublist(44), isNotEmpty);
  });

  test('onSegmentEvent reports started/ended live, in step with the detector', () async {
    final source = FakeAudioSource();
    var now = DateTime(2026);

    final segmenter = ClipSegmenter(
      audioSource: source,
      clock: () => now,
      clipsDirectory: () async => tempDir,
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 200),
      hangover: const Duration(milliseconds: 200),
      gracePeriod: Duration.zero,
      sampleRate: 10,
      numChannels: 1,
      bitsPerSample: 8,
    );

    final eventTypes = <SegmentEventType>[];
    segmenter.onSegmentEvent.listen((e) => eventTypes.add(e.type));

    await segmenter.start();

    Future<void> tick(int atMs, int pcmByte, double db) async {
      now = DateTime(2026).add(Duration(milliseconds: atMs));
      source.emitPcm(pcmByte);
      await pumpEventQueue();
      source.emitAmplitude(db);
      await pumpEventQueue();
    }

    await tick(0, 0xC0, -10);
    await tick(200, 0xC1, -10); // started
    expect(eventTypes, [SegmentEventType.started]);

    await tick(400, 0xC2, -40);
    await tick(600, 0xC3, -40); // ended
    expect(eventTypes, [SegmentEventType.started, SegmentEventType.ended]);

    await segmenter.stop();
  });

  test('dispose() closes onClipSaved and onSegmentEvent', () async {
    final segmenter = ClipSegmenter(
      audioSource: FakeAudioSource(),
      clipsDirectory: () async => tempDir,
    );

    var clipSavedClosed = false;
    var segmentEventClosed = false;
    segmenter.onClipSaved.listen(null, onDone: () => clipSavedClosed = true);
    segmenter.onSegmentEvent.listen(null, onDone: () => segmentEventClosed = true);

    await segmenter.dispose();
    await pumpEventQueue();

    expect(clipSavedClosed, isTrue);
    expect(segmentEventClosed, isTrue);
  });

  test('during the grace period, samples never reach the detector — no segment can open', () async {
    final source = FakeAudioSource();
    var now = DateTime(2026);

    final segmenter = ClipSegmenter(
      audioSource: source,
      clock: () => now,
      clipsDirectory: () async => tempDir,
      thresholdDb: -30,
      minSustained: const Duration(milliseconds: 200),
      hangover: const Duration(milliseconds: 200),
      gracePeriod: const Duration(milliseconds: 500),
      sampleRate: 10,
      numChannels: 1,
      bitsPerSample: 8,
    );

    final eventTypes = <SegmentEventType>[];
    segmenter.onSegmentEvent.listen((e) => eventTypes.add(e.type));

    await segmenter.start();

    Future<void> tick(int atMs, int pcmByte, double db) async {
      now = DateTime(2026).add(Duration(milliseconds: atMs));
      source.emitPcm(pcmByte);
      await pumpEventQueue();
      source.emitAmplitude(db);
      await pumpEventQueue();
    }

    // Loud for a full 200ms sustained streak, but entirely inside the 500ms
    // grace window — must not open a segment.
    await tick(0, 0xD0, -10);
    await tick(200, 0xD1, -10);
    expect(eventTypes, isEmpty);

    // Still loud, now past the grace window: the same sustained-duration
    // pattern opens a segment normally, timed from this point.
    await tick(500, 0xD2, -10);
    await tick(700, 0xD3, -10);
    expect(eventTypes, [SegmentEventType.started]);

    await segmenter.stop();
  });

  test('hasPermission delegates to the audio source', () async {
    final source = FakeAudioSource()..permissionGranted = false;
    final segmenter = ClipSegmenter(audioSource: source, clipsDirectory: () async => tempDir);

    expect(await segmenter.hasPermission(), isFalse);
  });
}

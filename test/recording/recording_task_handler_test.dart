import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/recording/audio_source.dart';
import 'package:nighttalker/recording/clip_segmenter.dart';
import 'package:nighttalker/recording/recording_task_handler.dart';
import 'package:nighttalker/settings/detection_settings.dart';

/// Same fake used by clip_segmenter_test.dart — kept local since test files
/// don't share fixtures across files in this project.
class FakeAudioSource implements AudioSource {
  final _pcmController = StreamController<Uint8List>.broadcast(sync: true);
  final _ampController = StreamController<double>.broadcast(sync: true);

  @override
  Future<bool> hasPermission() async => true;

  @override
  Stream<double> get amplitudeStream => _ampController.stream;

  @override
  Future<Stream<Uint8List>> startStream() async => _pcmController.stream;

  @override
  Future<void> stop() async {}

  void emitPcm(int byte) => _pcmController.add(Uint8List.fromList([byte]));
  void emitAmplitude(double db) => _ampController.add(db);
}

void main() {
  late Directory tempDir;
  late FakeAudioSource source;
  late ClipSegmenter segmenter;
  var now = DateTime(2026);
  final sentData = <Object>[];
  final notificationTexts = <String>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('recording_task_handler_test');
    source = FakeAudioSource();
    now = DateTime(2026);
    segmenter = ClipSegmenter(
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
    sentData.clear();
    notificationTexts.clear();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  RecordingTaskHandler buildHandler({Duration? autoStopCap, Future<void> Function()? stopService}) =>
      RecordingTaskHandler(
        segmenter: segmenter,
        sendData: sentData.add,
        updateNotificationText: notificationTexts.add,
        autoStopCap: autoStopCap,
        stopService: stopService,
      );

  Future<void> tick(int atMs, int pcmByte, double db) async {
    now = DateTime(2026).add(Duration(milliseconds: atMs));
    source.emitPcm(pcmByte);
    await pumpEventQueue();
    source.emitAmplitude(db);
    await pumpEventQueue();
  }

  test('onStart starts the segmenter and publishes an initial status', () async {
    final handler = buildHandler();

    await handler.onStart(DateTime(2026), TaskStarter.developer);

    expect(notificationTexts, isNotEmpty);
    expect(notificationTexts.last, contains('0 clips'));
  });

  test('forwards segment started/ended as messages and updates notification text', () async {
    final handler = buildHandler();
    await handler.onStart(DateTime(2026), TaskStarter.developer);

    await tick(0, 0xA0, -10);
    await tick(200, 0xA1, -10); // 200ms sustained: segment opens

    expect(sentData, contains(equals({'kind': 'segmentEvent', 'eventType': 'started'})));
    expect(notificationTexts.last, contains('Recording'));

    await tick(400, 0xA2, -40);
    await tick(600, 0xA3, -40); // 200ms quiet: segment closes

    expect(sentData, contains(equals({'kind': 'segmentEvent', 'eventType': 'ended'})));
    expect(notificationTexts.last, contains('Listening'));
  });

  test('forwards a saved clip path once written, and reflects the count in the notification', () async {
    final handler = buildHandler();
    await handler.onStart(DateTime(2026), TaskStarter.developer);

    await tick(0, 0xB0, -10);
    await tick(200, 0xB1, -10); // opens
    await tick(400, 0xB2, -40);
    await tick(600, 0xB3, -40); // closes -> saved

    final saved = sentData.where((d) => (d as Map)['kind'] == 'clipSaved');
    expect(saved, isNotEmpty);
    expect(notificationTexts.last, contains('1 clip'));
  });

  test('onDestroy finalizes a still-open clip before tearing down', () async {
    final handler = buildHandler();
    await handler.onStart(DateTime(2026), TaskStarter.developer);

    await tick(0, 0xC0, -10);
    await tick(200, 0xC1, -10); // segment open, never closed by hangover

    await handler.onDestroy(DateTime(2026), false);

    final saved = sentData.where((d) => (d as Map)['kind'] == 'clipSaved');
    expect(saved, isNotEmpty);
  });

  test('stops itself and notifies the UI once autoStopCap elapses', () async {
    var stopServiceCallCount = 0;
    final handler = buildHandler(
      autoStopCap: const Duration(milliseconds: 5),
      stopService: () async => stopServiceCallCount++,
    );

    await handler.onStart(DateTime(2026), TaskStarter.developer);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(stopServiceCallCount, 1);
    expect(sentData, contains(equals({'kind': 'autoStopped'})));
  });

  test('onDestroy cancels the pending auto-stop so it never fires after a manual stop', () async {
    var stopServiceCallCount = 0;
    final handler = buildHandler(
      autoStopCap: const Duration(milliseconds: 5),
      stopService: () async => stopServiceCallCount++,
    );

    await handler.onStart(DateTime(2026), TaskStarter.developer);
    await handler.onDestroy(DateTime(2026), false); // manual stop, before the cap
    await Future<void>.delayed(const Duration(milliseconds: 50)); // past when the cap would fire

    expect(stopServiceCallCount, 0);
  });

  test('onStart never loads settings when a segmenter is already provided', () async {
    var loadCount = 0;
    final handler = RecordingTaskHandler(
      segmenter: segmenter,
      sendData: sentData.add,
      updateNotificationText: notificationTexts.add,
      loadSettings: () async {
        loadCount++;
        return DetectionSettings.defaults;
      },
    );

    await handler.onStart(DateTime(2026), TaskStarter.developer);

    expect(loadCount, 0);
  });

  test('onStart loads settings and builds a segmenter that actually uses them', () async {
    var loadCount = 0;
    final fakeSource = FakeAudioSource();
    var buildNow = DateTime(2026);

    final handler = RecordingTaskHandler(
      sendData: sentData.add,
      updateNotificationText: notificationTexts.add,
      loadSettings: () async {
        loadCount++;
        return const DetectionSettings(
          thresholdDb: -10,
          minSustained: Duration(milliseconds: 100),
          hangover: Duration(milliseconds: 100),
          fallAsleepGracePeriod: Duration.zero,
        );
      },
      buildSegmenter: (settings) => ClipSegmenter(
        audioSource: fakeSource,
        clock: () => buildNow,
        clipsDirectory: () async => tempDir,
        thresholdDb: settings.thresholdDb,
        minSustained: settings.minSustained,
        hangover: settings.hangover,
        gracePeriod: settings.fallAsleepGracePeriod,
        sampleRate: 10,
        numChannels: 1,
        bitsPerSample: 8,
      ),
    );

    await handler.onStart(DateTime(2026), TaskStarter.developer);
    expect(loadCount, 1);

    // Drive it with the loaded settings' 100ms minSustained (not the
    // 200ms the shared `segmenter` in setUp uses) — a segment opening
    // here proves the loaded values actually reached the built segmenter.
    Future<void> tick(int atMs, int pcmByte, double db) async {
      buildNow = DateTime(2026).add(Duration(milliseconds: atMs));
      fakeSource.emitPcm(pcmByte);
      await pumpEventQueue();
      fakeSource.emitAmplitude(db);
      await pumpEventQueue();
    }

    await tick(0, 0xE0, -10);
    await tick(100, 0xE1, -10);

    expect(sentData, contains(equals({'kind': 'segmentEvent', 'eventType': 'started'})));
  });
}

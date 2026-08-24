import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/playback/clips_repository.dart';
import 'package:nighttalker/recording/wav_writer.dart';

Future<void> writeClip(Directory dir, int millis) async {
  final writer = WavWriter(sampleRate: 16000, numChannels: 1, bitsPerSample: 16)..addBytes(Uint8List(1600));
  await writer.writeToFile('${dir.path}/clip_$millis.wav');
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('clips_repository_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('lists clip files newest-first, ignoring files that are not clip_<millis>.wav', () async {
    await writeClip(tempDir, 100);
    await writeClip(tempDir, 300);
    await writeClip(tempDir, 200);
    await File('${tempDir.path}/session_999.m4a').writeAsBytes(Uint8List(10)); // step 1 leftover
    await File('${tempDir.path}/not_a_clip.txt').writeAsString('hello');

    final repository = ClipsRepository(clipsDirectory: () async => tempDir);
    final clips = await repository.listClips();

    expect(clips.map((c) => c.recordedAt.millisecondsSinceEpoch), [300, 200, 100]);
  });

  test('returns an empty list when the clips directory does not exist yet', () async {
    final missingDir = Directory('${tempDir.path}/does_not_exist');
    final repository = ClipsRepository(clipsDirectory: () async => missingDir);

    expect(await repository.listClips(), isEmpty);
  });
}

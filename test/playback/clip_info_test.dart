import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/playback/clip_info.dart';
import 'package:nighttalker/recording/wav_writer.dart';

void main() {
  group('parseRecordedAt', () {
    test('parses the millis out of a clip_<millis>.wav filename', () {
      final result = parseRecordedAt('clip_1787518920571.wav');

      expect(result, DateTime.fromMillisecondsSinceEpoch(1787518920571));
    });

    test('returns null for a filename not matching the clip_<millis>.wav pattern', () {
      expect(parseRecordedAt('session_1787516222246.m4a'), isNull);
      expect(parseRecordedAt('clip_not_a_number.wav'), isNull);
      expect(parseRecordedAt('not_a_clip_at_all.txt'), isNull);
    });
  });

  group('parseWavDuration', () {
    Uint8List buildHeader({
      int sampleRate = 16000,
      int numChannels = 1,
      int bitsPerSample = 16,
      required int dataSize,
    }) {
      final blockAlign = numChannels * bitsPerSample ~/ 8;
      final byteRate = sampleRate * blockAlign;
      final header = ByteData(44)
        ..setUint32(4, 36 + dataSize, Endian.little)
        ..setUint32(16, 16, Endian.little)
        ..setUint16(20, 1, Endian.little)
        ..setUint16(22, numChannels, Endian.little)
        ..setUint32(24, sampleRate, Endian.little)
        ..setUint32(28, byteRate, Endian.little)
        ..setUint16(32, blockAlign, Endian.little)
        ..setUint16(34, bitsPerSample, Endian.little)
        ..setUint32(40, dataSize, Endian.little);
      return header.buffer.asUint8List();
    }

    test('computes duration from sampleRate/channels/bits/dataSize in the header', () {
      // 16000 Hz, mono, 16-bit -> 32000 bytes/sec. 32000 bytes of data = 1s.
      final header = buildHeader(dataSize: 32000);

      expect(parseWavDuration(header), const Duration(seconds: 1));
    });

    test('returns null for bytes shorter than a full 44-byte header', () {
      expect(parseWavDuration(Uint8List(20)), isNull);
    });
  });

  group('ClipInfo.fromFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('clip_info_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('reads recordedAt, duration, and size from a real clip file', () async {
      final writer = WavWriter(sampleRate: 16000, numChannels: 1, bitsPerSample: 16)
        ..addBytes(Uint8List(32000)); // 1s of silence at 16kHz mono 16-bit
      final path = '${tempDir.path}/clip_1787518920571.wav';
      await writer.writeToFile(path);

      final info = await ClipInfo.fromFile(File(path));

      expect(info, isNotNull);
      expect(info!.path, path);
      expect(info.recordedAt, DateTime.fromMillisecondsSinceEpoch(1787518920571));
      expect(info.duration, const Duration(seconds: 1));
      expect(info.sizeInBytes, 44 + 32000);
    });

    test('returns null for a file whose name is not a clip_<millis>.wav', () async {
      final path = '${tempDir.path}/not_a_clip.wav';
      await File(path).writeAsBytes(Uint8List(44));

      expect(await ClipInfo.fromFile(File(path)), isNull);
    });
  });
}

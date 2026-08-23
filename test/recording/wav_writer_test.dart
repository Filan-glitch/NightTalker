import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/recording/wav_writer.dart';

void main() {
  test('produces a valid 44-byte RIFF/WAVE header followed by the PCM bytes', () {
    final writer = WavWriter(sampleRate: 16000, numChannels: 1, bitsPerSample: 16);
    final pcm = Uint8List.fromList(List.generate(8, (i) => i));
    writer.addBytes(pcm);

    final bytes = writer.toWavBytes();
    final data = ByteData.sublistView(bytes);

    expect(bytes.length, 44 + pcm.length);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(data.getUint32(4, Endian.little), 36 + pcm.length); // ChunkSize
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
    expect(data.getUint32(16, Endian.little), 16); // Subchunk1Size (PCM)
    expect(data.getUint16(20, Endian.little), 1); // AudioFormat (PCM)
    expect(data.getUint16(22, Endian.little), 1); // NumChannels
    expect(data.getUint32(24, Endian.little), 16000); // SampleRate
    expect(data.getUint32(28, Endian.little), 16000 * 1 * 16 ~/ 8); // ByteRate
    expect(data.getUint16(32, Endian.little), 1 * 16 ~/ 8); // BlockAlign
    expect(data.getUint16(34, Endian.little), 16); // BitsPerSample
    expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    expect(data.getUint32(40, Endian.little), pcm.length); // Subchunk2Size
    expect(bytes.sublist(44), pcm);
  });

  test('accumulates multiple addBytes calls in order', () {
    final writer = WavWriter(sampleRate: 16000, numChannels: 1, bitsPerSample: 16);
    writer.addBytes(Uint8List.fromList([1, 2, 3]));
    writer.addBytes(Uint8List.fromList([4, 5]));

    final bytes = writer.toWavBytes();

    expect(bytes.sublist(44), [1, 2, 3, 4, 5]);
  });
}

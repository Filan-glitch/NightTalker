import 'dart:io';
import 'dart:typed_data';

/// Builds a single WAV (RIFF/PCM) file's bytes in memory from raw PCM
/// chunks, then writes it to disk in one shot.
///
/// Clips are short (seconds, not hours), so buffering the whole clip's PCM
/// before writing avoids the complexity of streaming to disk and patching
/// the header's size fields after the fact.
class WavWriter {
  WavWriter({required this.sampleRate, required this.numChannels, required this.bitsPerSample});

  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;

  final BytesBuilder _pcm = BytesBuilder(copy: false);

  /// Appends raw PCM bytes captured so far for this clip.
  void addBytes(Uint8List bytes) => _pcm.add(bytes);

  int get pcmLengthInBytes => _pcm.length;

  /// Builds the full WAV file: a 44-byte RIFF header followed by the PCM
  /// bytes accumulated via [addBytes].
  Uint8List toWavBytes() {
    final pcm = _pcm.toBytes();
    final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final blockAlign = numChannels * bitsPerSample ~/ 8;

    final header = ByteData(44)
      ..setUint8(0, 0x52) // 'R'
      ..setUint8(1, 0x49) // 'I'
      ..setUint8(2, 0x46) // 'F'
      ..setUint8(3, 0x46) // 'F'
      ..setUint32(4, 36 + pcm.length, Endian.little)
      ..setUint8(8, 0x57) // 'W'
      ..setUint8(9, 0x41) // 'A'
      ..setUint8(10, 0x56) // 'V'
      ..setUint8(11, 0x45) // 'E'
      ..setUint8(12, 0x66) // 'f'
      ..setUint8(13, 0x6d) // 'm'
      ..setUint8(14, 0x74) // 't'
      ..setUint8(15, 0x20) // ' '
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, numChannels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      ..setUint8(36, 0x64) // 'd'
      ..setUint8(37, 0x61) // 'a'
      ..setUint8(38, 0x74) // 't'
      ..setUint8(39, 0x61) // 'a'
      ..setUint32(40, pcm.length, Endian.little);

    return Uint8List(44 + pcm.length)
      ..setRange(0, 44, header.buffer.asUint8List())
      ..setRange(44, 44 + pcm.length, pcm);
  }

  /// Writes the built WAV file to [path].
  Future<void> writeToFile(String path) => File(path).writeAsBytes(toWavBytes());
}

import 'dart:io';
import 'dart:typed_data';

final _clipFilenamePattern = RegExp(r'^clip_(\d+)\.wav$');

/// A saved clip, as shown in the results screen.
class ClipInfo {
  const ClipInfo({required this.path, required this.recordedAt, required this.duration, required this.sizeInBytes});

  final String path;
  final DateTime recordedAt;
  final Duration duration;
  final int sizeInBytes;

  /// Reads a [ClipInfo] from a clip file on disk. Only reads the first 44
  /// bytes (the WAV header) plus a length stat — never the whole clip.
  /// Returns null if [file]'s name isn't a `clip_<millis>.wav` or its header
  /// isn't a valid WAV header.
  static Future<ClipInfo?> fromFile(File file) async {
    final recordedAt = parseRecordedAt(file.uri.pathSegments.last);
    if (recordedAt == null) return null;

    final raf = await file.open();
    try {
      final header = await raf.read(44);
      final duration = parseWavDuration(header);
      if (duration == null) return null;

      return ClipInfo(path: file.path, recordedAt: recordedAt, duration: duration, sizeInBytes: await file.length());
    } finally {
      await raf.close();
    }
  }
}

/// Decodes the `clip_<millisSinceEpoch>.wav` naming [ClipSegmenter] writes.
/// Returns null for anything that doesn't match — including step 1's old
/// `session_*.m4a` files, in case any are still lying around on a device.
DateTime? parseRecordedAt(String filename) {
  final match = _clipFilenamePattern.firstMatch(filename);
  if (match == null) return null;

  final millis = int.tryParse(match.group(1)!);
  if (millis == null) return null;

  return DateTime.fromMillisecondsSinceEpoch(millis);
}

/// Computes a clip's playback duration straight from its own WAV header
/// (sampleRate/numChannels/bitsPerSample/dataSize) — self-describing, so it
/// stays correct even if [WavWriter]'s defaults ever change, and only needs
/// the first 44 bytes of the file, not the whole clip.
Duration? parseWavDuration(Uint8List header) {
  if (header.length < 44) return null;

  final data = ByteData.sublistView(header);
  final sampleRate = data.getUint32(24, Endian.little);
  final numChannels = data.getUint16(22, Endian.little);
  final bitsPerSample = data.getUint16(34, Endian.little);
  final dataSize = data.getUint32(40, Endian.little);

  final bytesPerSecond = sampleRate * numChannels * bitsPerSample ~/ 8;
  if (bytesPerSecond <= 0) return null;

  final microseconds = (dataSize * Duration.microsecondsPerSecond) ~/ bytesPerSecond;
  return Duration(microseconds: microseconds);
}

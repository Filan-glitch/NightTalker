import 'dart:typed_data';

/// Fixed-capacity circular buffer of raw PCM bytes: holds only the most
/// recently added [maxBytes], oldest data dropped first.
///
/// [ClipSegmenter] keeps one of these sized to
/// [DetectionConstants.minSustainedDuration] running continuously, so when a
/// segment opens it has the audio leading up to the threshold-confirming
/// sample already in hand (the "pre-roll") instead of starting the clip mid-word.
class PcmRingBuffer {
  PcmRingBuffer({required this.maxBytes}) : assert(maxBytes > 0);

  final int maxBytes;

  final List<int> _buffer = [];

  /// Appends [bytes], dropping the oldest bytes if that pushes the buffer
  /// past [maxBytes].
  void add(Uint8List bytes) {
    _buffer.addAll(bytes);
    if (_buffer.length > maxBytes) {
      _buffer.removeRange(0, _buffer.length - maxBytes);
    }
  }

  /// The bytes currently held, oldest first.
  Uint8List snapshot() => Uint8List.fromList(_buffer);
}

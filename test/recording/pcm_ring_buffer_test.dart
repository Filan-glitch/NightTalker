import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nighttalker/recording/pcm_ring_buffer.dart';

void main() {
  test('snapshot returns everything added while under capacity', () {
    final buffer = PcmRingBuffer(maxBytes: 10);
    buffer.add(Uint8List.fromList([1, 2, 3]));

    expect(buffer.snapshot(), [1, 2, 3]);
  });

  test('snapshot keeps only the most recent maxBytes, in order, once over capacity', () {
    final buffer = PcmRingBuffer(maxBytes: 4);
    buffer.add(Uint8List.fromList([1, 2, 3]));
    buffer.add(Uint8List.fromList([4, 5, 6]));

    // 6 bytes added, capacity 4: only the last 4 survive, oldest-first.
    expect(buffer.snapshot(), [3, 4, 5, 6]);
  });
}

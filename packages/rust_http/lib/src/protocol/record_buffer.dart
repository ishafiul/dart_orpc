import 'dart:typed_data';

/// A growable byte buffer that records are written into.
///
/// The FFI engine backs it with native memory, because a non-leaf FFI call
/// cannot read the Dart heap; tests use [HeapRecordBuffer].
abstract interface class RecordBuffer {
  /// The current storage. Replaced when the buffer grows.
  Uint8List get bytes;

  /// A [ByteData] view of [bytes].
  ByteData get data;

  /// Makes room for [length] bytes in total.
  void ensureCapacity(int length);
}

/// A [RecordBuffer] on the Dart heap.
final class HeapRecordBuffer implements RecordBuffer {
  /// Creates a buffer of [initialCapacity] bytes.
  HeapRecordBuffer([int initialCapacity = 256])
    : bytes = Uint8List(initialCapacity);

  @override
  Uint8List bytes;

  @override
  ByteData get data => ByteData.sublistView(bytes);

  @override
  void ensureCapacity(int length) {
    if (length <= bytes.length) return;
    var size = bytes.length * 2;
    while (size < length) {
      size *= 2;
    }
    bytes = Uint8List(size)..setRange(0, bytes.length, bytes);
  }
}

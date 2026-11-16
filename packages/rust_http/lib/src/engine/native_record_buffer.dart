import 'dart:ffi';
import 'dart:typed_data';

import '../ffi/bindings.dart';
import '../protocol/record_buffer.dart';

/// A [RecordBuffer] in native memory: `rust_http_run` is not a leaf call,
/// so it cannot read bytes on the Dart heap.
final class NativeRecordBuffer implements RecordBuffer {
  /// A buffer of [capacity] bytes.
  NativeRecordBuffer(int capacity) : _pointer = rustHttpAlloc(capacity) {
    bytes = _pointer.asTypedList(capacity);
    data = ByteData.sublistView(bytes);
  }

  Pointer<Uint8> _pointer;

  @override
  late Uint8List bytes;

  @override
  late ByteData data;

  /// The native address, for FFI calls.
  Pointer<Uint8> get pointer => _pointer;

  @override
  void ensureCapacity(int length) {
    if (length <= bytes.length) return;
    var size = bytes.length * 2;
    while (size < length) {
      size *= 2;
    }
    _replace(size, keep: bytes.length);
  }

  /// Shrinks back to [capacity] when the buffer grew past [threshold], so a
  /// single large body does not pin memory forever.
  void shrinkIfAbove(int threshold, int capacity) {
    if (bytes.length > threshold) _replace(capacity, keep: 0);
  }

  /// Frees the memory. The buffer must not be used afterwards.
  void free() => rustHttpFree(_pointer, bytes.length);

  void _replace(int size, {required int keep}) {
    final next = rustHttpAlloc(size);
    final grown = next.asTypedList(size)..setRange(0, keep, bytes);
    rustHttpFree(_pointer, bytes.length);
    _pointer = next;
    bytes = grown;
    data = ByteData.sublistView(grown);
  }
}

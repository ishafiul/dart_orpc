import 'dart:typed_data';

/// The body of a response while it is buffered. One chunk is kept as it
/// is; more chunks are joined without copying until taken.
final class BodyBuffer {
  List<int>? _first;
  BytesBuilder? _more;
  int _length = 0;

  /// Bytes buffered.
  int get length => _length;

  /// Whether nothing is buffered.
  bool get isEmpty => _length == 0;

  /// Buffers [data]. The list must not change afterwards.
  void add(List<int> data) {
    _length += data.length;
    final first = _first;
    if (first == null) {
      _first = data;
      return;
    }
    (_more ??= BytesBuilder(copy: false)..add(first)).add(data);
  }

  /// The buffered bytes, leaving the buffer empty.
  List<int> take() {
    final more = _more;
    final body = more != null ? more.takeBytes() : _first ?? const <int>[];
    _first = null;
    _more = null;
    _length = 0;
    return body;
  }
}

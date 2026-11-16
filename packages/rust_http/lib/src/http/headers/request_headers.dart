import 'dart:io';
import 'dart:typed_data';

import 'rust_http_headers.dart';

/// Headers of a request, read from the header block Rust wrote.
///
/// Each header in the block is `u16` name length, `u16` value length, the
/// lowercase name, the value. A lookup scans the block for one name, so a
/// handler that reads a few headers decodes no others; after
/// [_maxScans] lookups the block is decoded into a map once.
final class RequestHeaders extends RustHttpHeaders {
  /// Headers over [raw], a view into the request batch.
  RequestHeaders(Uint8List raw, {required bool http10})
    : _raw = raw,
      _http10 = http10;

  /// Lookups done by scanning before all headers are decoded. A scan that
  /// finds nothing allocates nothing, and a few scans cost less than a map.
  static const int _maxScans = 4;

  Uint8List? _raw;
  final bool _http10;
  Map<String, List<String>>? _map;
  int _scans = 0;

  @override
  bool get isHttp10 => _http10;

  /// Stops viewing the batch: keeps a copy of the raw bytes, or none once
  /// decoded.
  void detach() {
    final raw = _raw;
    if (raw == null) return;
    _raw = _map == null ? Uint8List.fromList(raw) : null;
  }

  @override
  List<String>? lookup(String name) {
    final map = _map;
    if (map != null) return map[name];
    if (++_scans > _maxScans) return _decoded[name];
    return _scan(_raw!, name);
  }

  Map<String, List<String>> get _decoded => _map ??= _decode(_raw!);

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _decoded.forEach(action);
  }

  @override
  int get contentLength {
    final text = value(HttpHeaders.contentLengthHeader);
    return text == null ? -1 : int.tryParse(text) ?? -1;
  }

  @override
  bool get chunkedTransferEncoding =>
      value(HttpHeaders.transferEncodingHeader)
          ?.toLowerCase()
          .contains('chunked') ??
      false;

  static Map<String, List<String>> _decode(Uint8List b) {
    final out = <String, List<String>>{};
    var at = 0;
    while (at + 4 <= b.length) {
      final nameEnd = at + 4 + (b[at] | b[at + 1] << 8);
      final end = nameEnd + (b[at + 2] | b[at + 3] << 8);
      final name = String.fromCharCodes(b, at + 4, nameEnd);
      (out[name] ??= []).add(String.fromCharCodes(b, nameEnd, end));
      at = end;
    }
    return out;
  }

  static List<String>? _scan(Uint8List b, String name) {
    List<String>? out;
    var at = 0;
    while (at + 4 <= b.length) {
      final nameLength = b[at] | b[at + 1] << 8;
      final nameEnd = at + 4 + nameLength;
      final end = nameEnd + (b[at + 2] | b[at + 3] << 8);
      if (nameLength == name.length && _matches(b, at + 4, name)) {
        (out ??= []).add(String.fromCharCodes(b, nameEnd, end));
      }
      at = end;
    }
    return out;
  }

  static bool _matches(Uint8List b, int at, String name) {
    for (var i = 0; i < name.length; i++) {
      if (b[at + i] != name.codeUnitAt(i)) return false;
    }
    return true;
  }

  Never _immutable() =>
      throw const HttpException('HTTP headers are not mutable');

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) =>
      _immutable();

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      _immutable();

  @override
  void remove(String name, Object value) => _immutable();

  @override
  void removeAll(String name) => _immutable();

  @override
  void clear() => _immutable();

  @override
  set contentLength(int length) => _immutable();

  @override
  set chunkedTransferEncoding(bool chunked) => _immutable();

  @override
  set contentType(ContentType? type) => _immutable();

  @override
  set persistentConnection(bool keep) => _immutable();

  @override
  set date(DateTime? date) => _immutable();

  @override
  set expires(DateTime? expires) => _immutable();

  @override
  set ifModifiedSince(DateTime? date) => _immutable();

  @override
  set host(String? host) => _immutable();

  @override
  set port(int? port) => _immutable();
}

import 'dart:io';

import 'header_validation.dart';
import 'rust_http_headers.dart';

/// Mutable headers of a response, or the server's default headers.
///
/// A response starts as a view of the server defaults and copies them on
/// the first change (copy on write), so a plain response copies nothing.
/// Setting only [contentType] keeps them shared too: the server then uses
/// cached bytes for "defaults plus this type".
final class ResponseHeaders extends RustHttpHeaders {
  /// Headers of a response that start as [defaults].
  ResponseHeaders(ResponseHeaders defaults)
    : _entries = defaults._map,
      _shared = true;

  /// An empty set, such as the server defaults.
  ResponseHeaders.empty() : _entries = {}, _shared = false;

  /// The defaults while shared, else this response's own map.
  Map<String, List<String>> _entries;
  bool _shared;

  /// A content type set while still shared.
  ContentType? _sharedType;
  String? _sharedTypeText;

  int _contentLength = -1;
  bool _chunked = false;

  /// Counts changes, so a cache of encoded header bytes can tell it is old.
  int version = 0;

  static ContentType? _lastType;
  static String? _lastTypeText;

  @override
  bool get isHttp10 => false;

  /// Whether these are still the untouched defaults.
  bool get isShared => _shared && _sharedType == null;

  /// The content type when the headers are the defaults plus only this
  /// type; else null.
  ContentType? get sharedType => _shared ? _sharedType : null;

  Map<String, List<String>> get _map {
    if (_sharedType != null) _unshare();
    return _entries;
  }

  /// Copies the shared defaults so they can change.
  void _unshare() {
    final type = _sharedTypeText;
    _sharedType = null;
    _sharedTypeText = null;
    _shared = false;
    _entries = {
      for (final entry in _entries.entries) entry.key: List.of(entry.value),
      if (type != null) HttpHeaders.contentTypeHeader: [type],
    };
  }

  Map<String, List<String>> _own() {
    version++;
    if (_shared) _unshare();
    return _entries;
  }

  @override
  List<String>? lookup(String name) {
    if (name == HttpHeaders.contentLengthHeader) {
      return _contentLength < 0 ? null : ['$_contentLength'];
    }
    final type = _sharedTypeText;
    if (type != null && name == HttpHeaders.contentTypeHeader) return [type];
    return _entries[name];
  }

  /// Every header line for the wire. `content-length` and
  /// `transfer-encoding` are left out: Rust frames the body.
  void forEachLine(void Function(String name, String value) write) {
    for (final entry in _map.entries) {
      for (final value in entry.value) {
        write(entry.key, value);
      }
    }
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _map.forEach(action);
    if (_contentLength >= 0) {
      action(HttpHeaders.contentLengthHeader, ['$_contentLength']);
    }
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    name = checkHeaderName(name.toLowerCase());
    if (_setsLength(name, value)) return;
    // Check every value first: a bad one changes nothing.
    final values = _values(value);
    (_own()[name] ??= []).addAll(values);
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    name = checkHeaderName(name.toLowerCase());
    if (_setsLength(name, value)) return;
    final values = _values(value);
    _own()[name] = values;
  }

  @override
  void remove(String name, Object value) {
    name = name.toLowerCase();
    if (name == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
      return;
    }
    final values = _own()[name];
    if (values == null) return;
    values.remove(_text(value));
    if (values.isEmpty) _entries.remove(name);
  }

  @override
  void removeAll(String name) {
    name = name.toLowerCase();
    if (name == HttpHeaders.contentLengthHeader) {
      _contentLength = -1;
      return;
    }
    _own().remove(name);
  }

  @override
  void clear() {
    _own().clear();
    _contentLength = -1;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int length) => _contentLength = length;

  @override
  bool get chunkedTransferEncoding => _chunked;

  @override
  set chunkedTransferEncoding(bool chunked) => _chunked = chunked;

  @override
  set contentType(ContentType? type) {
    if (type == null) {
      removeAll(HttpHeaders.contentTypeHeader);
      return;
    }
    // Apps set the same const types again and again: keep the checked
    // text of the last one. ContentType does not check its parts, so a
    // line break there would inject a header.
    if (!identical(type, _lastType)) {
      _lastTypeText = checkHeaderValue(type.toString());
      _lastType = type;
    }
    final text = _lastTypeText!;
    if (_shared) {
      _sharedType = type;
      _sharedTypeText = text;
    } else {
      set(HttpHeaders.contentTypeHeader, text);
    }
    cacheContentType(type, text);
  }

  @override
  set persistentConnection(bool keep) {
    if (keep) {
      removeAll(HttpHeaders.connectionHeader);
    } else {
      set(HttpHeaders.connectionHeader, 'close');
    }
  }

  @override
  set date(DateTime? date) => _setDate(HttpHeaders.dateHeader, date);

  @override
  set expires(DateTime? expires) =>
      _setDate(HttpHeaders.expiresHeader, expires);

  @override
  set ifModifiedSince(DateTime? date) =>
      _setDate(HttpHeaders.ifModifiedSinceHeader, date);

  @override
  set host(String? host) {
    if (host == null) {
      removeAll(HttpHeaders.hostHeader);
    } else {
      final port = this.port;
      set(HttpHeaders.hostHeader, port == null ? host : '$host:$port');
    }
  }

  @override
  set port(int? port) {
    final host = this.host;
    if (host != null) {
      set(HttpHeaders.hostHeader, port == null ? host : '$host:$port');
    }
  }

  void _setDate(String name, DateTime? date) {
    if (date == null) {
      removeAll(name);
    } else {
      set(name, HttpDate.format(date.toUtc()));
    }
  }

  /// `content-length` is kept as a number, like dart:io.
  bool _setsLength(String name, Object value) {
    if (name != HttpHeaders.contentLengthHeader) return false;
    _contentLength = value is int ? value : int.parse(_text(value));
    return true;
  }

  static List<String> _values(Object value) {
    if (value is Iterable<Object?>) {
      return [for (final v in value) checkHeaderValue(_text(v))];
    }
    return [checkHeaderValue(_text(value))];
  }

  static String _text(Object? value) =>
      value is DateTime ? HttpDate.format(value) : '$value';
}

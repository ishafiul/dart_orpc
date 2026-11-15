import 'dart:io';

/// [HttpHeaders] of the Rust-backed server.
///
/// The reading half of the interface is shared here; `RequestHeaders` and
/// `ResponseHeaders` add how values are stored.
abstract base class RustHttpHeaders implements HttpHeaders {
  /// The values of [name], which is lowercase, or null.
  List<String>? lookup(String name);

  /// Whether the headers belong to an HTTP/1.0 message.
  bool get isHttp10;

  ContentType? _contentType;
  String? _contentTypeSource;

  @override
  List<String>? operator [](String name) => lookup(name.toLowerCase());

  @override
  String? value(String name) {
    final values = this[name];
    if (values == null) return null;
    if (values.length > 1) {
      throw HttpException('More than one value for header $name');
    }
    return values.single;
  }

  @override
  ContentType? get contentType {
    final text = value(HttpHeaders.contentTypeHeader);
    if (text == null) return null;
    if (text != _contentTypeSource) {
      _contentType = ContentType.parse(text);
      _contentTypeSource = text;
    }
    return _contentType;
  }

  /// Remembers [type] as the parsed form of [text], so the getter needs no
  /// parse after the setter.
  void cacheContentType(ContentType type, String text) {
    _contentType = type;
    _contentTypeSource = text;
  }

  @override
  bool get persistentConnection {
    final connection = lookup(HttpHeaders.connectionHeader)
        ?.join(',')
        .toLowerCase();
    if (connection == null) return !isHttp10;
    if (connection.contains('close')) return false;
    return !isHttp10 || connection.contains('keep-alive');
  }

  @override
  DateTime? get date => _date(HttpHeaders.dateHeader);

  @override
  DateTime? get expires => _date(HttpHeaders.expiresHeader);

  @override
  DateTime? get ifModifiedSince => _date(HttpHeaders.ifModifiedSinceHeader);

  @override
  String? get host {
    final text = value(HttpHeaders.hostHeader);
    if (text == null) return null;
    if (text.startsWith('[')) {
      final end = text.indexOf(']');
      return end < 0 ? text : text.substring(1, end);
    }
    final colon = text.indexOf(':');
    return colon < 0 ? text : text.substring(0, colon);
  }

  @override
  int? get port {
    final text = value(HttpHeaders.hostHeader);
    if (text == null) return null;
    final colon = text.lastIndexOf(':');
    if (colon < 0 || colon < text.lastIndexOf(']')) return null;
    return int.tryParse(text.substring(colon + 1));
  }

  @override
  void noFolding(String name) {}

  @override
  String toString() {
    final out = StringBuffer();
    forEach((name, values) {
      for (final value in values) {
        out.write('$name: $value\n');
      }
    });
    return out.toString();
  }

  DateTime? _date(String name) {
    final text = value(name);
    if (text == null) return null;
    try {
      return HttpDate.parse(text);
    } on Exception {
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../protocol/outbound_record_writer.dart';
import '../answer_channel.dart';
import '../headers/response_headers.dart';

/// Writes the header lines of answers.
///
/// Most answers carry the untouched server defaults, or the defaults with
/// one content type; both are cached as encoded bytes, so a typical answer
/// writes its headers with one copy.
final class HeaderLineEncoder {
  /// An encoder over the server's default headers.
  HeaderLineEncoder(this._defaults);

  final ResponseHeaders _defaults;

  Uint8List _defaultLines = Uint8List(0);
  int _defaultVersion = -1;

  ContentType? _typedFor;
  Uint8List _typedLines = Uint8List(0);
  int _typedVersion = -1;

  /// The `server` header value, already validated.
  String? serverHeader;

  /// Writes the lines of [source] into [writer]. Returns whether they
  /// contain `connection: close`. `content-length` is written only when
  /// [withLength], because Rust frames whole bodies itself.
  bool write(
    OutboundRecordWriter writer,
    AnswerSource source, {
    bool withLength = false,
  }) {
    final headers = source.headers;
    final type = headers.sharedType;
    final cached = headers.isShared
        ? _defaultsBytes()
        : (type == null ? null : _typedBytes(type));
    var saysClose = false;
    void line(String name, String value) {
      if (name == HttpHeaders.contentLengthHeader ||
          name == HttpHeaders.transferEncodingHeader) {
        return; // Rust frames the body.
      }
      if (name == HttpHeaders.connectionHeader &&
          value.toLowerCase().contains('close')) {
        saysClose = true;
      }
      writer.headerLine(name, value);
    }

    if (cached != null) {
      writer.headerBytes(cached);
    } else {
      headers.forEachLine(line);
    }
    final server = serverHeader;
    if (server != null) line(HttpHeaders.serverHeader, server);
    if (source.hasCookies) {
      for (final cookie in source.cookies) {
        line(HttpHeaders.setCookieHeader, cookie.toString());
      }
    }
    final length = headers.contentLength;
    if (withLength && length >= 0) {
      writer.headerLine(HttpHeaders.contentLengthHeader, '$length');
    }
    return saysClose;
  }

  Uint8List _defaultsBytes() {
    if (_defaults.version != _defaultVersion) {
      _defaultLines = _encode(skipContentType: false);
      _defaultVersion = _defaults.version;
    }
    return _defaultLines;
  }

  /// The defaults with another content type, cached for the last type:
  /// most apps answer with one type (e.g. JSON).
  Uint8List _typedBytes(ContentType type) {
    if (!identical(type, _typedFor) || _defaults.version != _typedVersion) {
      final builder = BytesBuilder(copy: false)
        ..add(_encode(skipContentType: true))
        ..add(latin1.encode('${HttpHeaders.contentTypeHeader}: $type\r\n'));
      _typedLines = builder.takeBytes();
      _typedFor = type;
      _typedVersion = _defaults.version;
    }
    return _typedLines;
  }

  Uint8List _encode({required bool skipContentType}) {
    final builder = BytesBuilder(copy: false);
    _defaults.forEachLine((name, value) {
      if (skipContentType && name == HttpHeaders.contentTypeHeader) return;
      builder.add(latin1.encode('$name: $value\r\n'));
    });
    return builder.takeBytes();
  }
}

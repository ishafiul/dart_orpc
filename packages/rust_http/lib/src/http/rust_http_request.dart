import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../protocol/inbound_record.dart';
import '../websocket/websocket_host.dart';
import 'answer_channel.dart';
import 'headers/request_headers.dart';
import 'response/rust_http_response.dart';

/// [HttpRequest] of the Rust-backed server.
///
/// The whole body is already read — Rust answers 413 past the limit — so
/// the stream delivers it in one event.
final class RustHttpRequest extends Stream<Uint8List> implements HttpRequest {
  /// A request decoded from [record].
  RustHttpRequest(this._channel, this.webSocketHost, RequestRecord record)
    : id = record.id,
      method = record.method,
      _target = record.target,
      _rawHeaders = record.rawHeaders,
      _body = record.body,
      _remoteIp = record.remoteIp,
      _remotePort = record.remotePort,
      _http10 = record.http10,
      isWebSocketUpgrade = record.isWebSocketUpgrade;

  final AnswerChannel _channel;

  /// The server, for a WebSocket upgrade.
  final WebSocketHost webSocketHost;

  /// The id of the request in the engine.
  final int id;

  @override
  final String method;

  final String _target;
  Uint8List _rawHeaders;
  Uint8List _body;
  Uint8List _remoteIp;
  final int _remotePort;
  final bool _http10;

  /// Whether Rust found a valid WebSocket upgrade request.
  final bool isWebSocketUpgrade;

  RequestHeaders? _headers;
  // The handler closes the response; the request only creates it.
  // ignore: close_sinks
  RustHttpResponse? _response;

  static final Uint8List _empty = Uint8List(0);

  @override
  RequestHeaders get headers =>
      _headers ??= RequestHeaders(_rawHeaders, http10: _http10);

  /// The body bytes, the same the stream delivers.
  Uint8List get body => _body;

  @override
  late final Uri uri = _parseTarget(_target);

  @override
  RustHttpResponse get response => _response ??= RustHttpResponse(
    _channel,
    requestId: id,
    acceptEncoding: headers.value(HttpHeaders.acceptEncodingHeader),
    connectionInfo: connectionInfo,
  );

  /// Whether the response was sent or upgraded.
  bool get isAnswered => _response?.isClosed ?? false;

  @override
  int get contentLength => headers.chunkedTransferEncoding ? -1 : _body.length;

  @override
  Uri get requestedUri {
    final host = headers.value(HttpHeaders.hostHeader) ?? '127.0.0.1';
    return Uri.parse('http://$host$_target');
  }

  @override
  late final List<Cookie> cookies = _parseCookies();

  @override
  bool get persistentConnection => headers.persistentConnection;

  @override
  String get protocolVersion => _http10 ? '1.0' : '1.1';

  @override
  X509Certificate? get certificate => null;

  @override
  HttpSession get session =>
      throw UnsupportedError('rust_http has no HttpSession');

  @override
  late final HttpConnectionInfo connectionInfo = _ConnectionInfo(
    _remoteAddress(_remoteIp),
    _remotePort,
    _channel.localPort,
  );

  /// Stops viewing [batch]: copies the bytes this request holds from it, so
  /// a request that outlives its batch does not keep the whole batch alive.
  /// Bytes from elsewhere (a body in native memory) stay as they are.
  void detach(List<int> batch) {
    final buffer = batch is Uint8List ? batch.buffer : null;
    final headers = _headers;
    if (headers != null) {
      headers.detach();
      _rawHeaders = _empty;
    } else if (_rawHeaders.buffer == buffer) {
      _rawHeaders = Uint8List.fromList(_rawHeaders);
    }
    if (_body.buffer == buffer) _body = Uint8List.fromList(_body);
    if (_remoteIp.buffer == buffer) _remoteIp = Uint8List.fromList(_remoteIp);
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = _body.isEmpty
        ? const Stream<Uint8List>.empty()
        : Stream<Uint8List>.value(_body);
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// The peer address. Rust reports IPv4 peers as IPv4-mapped IPv6;
  /// dart:io reports them as plain IPv4, so they are unmapped here.
  static InternetAddress _remoteAddress(Uint8List ip) {
    var mapped = ip.length == 16 && ip[10] == 0xff && ip[11] == 0xff;
    for (var i = 0; mapped && i < 10; i++) {
      mapped = ip[i] == 0;
    }
    return InternetAddress.fromRawAddress(
      mapped ? Uint8List.sublistView(ip, 12) : ip,
    );
  }

  /// A plain path skips the full parse; the result is the same.
  static Uri _parseTarget(String target) {
    final plain =
        target.startsWith('/') &&
        !target.startsWith('//') &&
        !target.contains('?') &&
        !target.contains('#');
    return plain ? Uri(path: target) : Uri.parse(target);
  }

  List<Cookie> _parseCookies() {
    final out = <Cookie>[];
    for (final header
        in headers[HttpHeaders.cookieHeader] ?? const <String>[]) {
      for (final part in header.split(';')) {
        final equals = part.indexOf('=');
        if (equals <= 0) continue;
        try {
          out.add(
            Cookie(
              part.substring(0, equals).trim(),
              part.substring(equals + 1).trim(),
            ),
          );
        } on FormatException {
          // Skip a cookie with invalid characters.
        }
      }
    }
    return out;
  }
}

final class _ConnectionInfo implements HttpConnectionInfo {
  _ConnectionInfo(this.remoteAddress, this.remotePort, this.localPort);

  @override
  final InternetAddress remoteAddress;

  @override
  final int remotePort;

  @override
  final int localPort;
}

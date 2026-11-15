import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../http/headers/header_validation.dart';
import '../http/rust_http_request.dart';
import '../protocol/kinds.dart';
import 'websocket_host.dart';

/// A WebSocket on the Rust-backed server.
///
/// Rust marks requests that can upgrade; Dart routes and checks them like
/// any request, then [upgrade] accepts. Rust then speaks the protocol:
/// ping and pong, the close handshake, the UTF-8 check of text and the
/// size limit (a larger message closes with 1009). Compression is never
/// agreed. Dart receives whole messages: a [String] for text, a
/// [Uint8List] for binary.
///
/// It implements the `dart:io` [WebSocket] API.
final class RustWebSocket extends Stream<dynamic>
    implements WebSocket, WebSocketReceiver {
  RustWebSocket._(this._host, this._id, this.protocol);

  /// Whether [request] asks for a WebSocket upgrade.
  static bool isUpgradeRequest(HttpRequest request) {
    if (request is RustHttpRequest) return request.isWebSocketUpgrade;
    return WebSocketTransformer.isUpgradeRequest(request);
  }

  /// Accepts the upgrade of [request].
  ///
  /// The answer names [protocol] as the subprotocol, or else the value of
  /// [protocolSelector], which gets the protocols the client offered and
  /// is only called when it offered some — like `WebSocketTransformer`.
  /// A message or frame over [maxMessageSize] bytes closes the socket with
  /// 1009 before Dart sees it. [compression] exists for
  /// `WebSocketTransformer.upgrade` compatibility: compression is never
  /// agreed.
  ///
  /// A request that is no upgrade gets 400 and the future fails with a
  /// [WebSocketException]. For a `dart:io` request, [compression] is passed
  /// to `WebSocketTransformer`.
  static Future<WebSocket> upgrade(
    HttpRequest request, {
    String? protocol,
    Object? Function(List<String> protocols)? protocolSelector,
    CompressionOptions compression = CompressionOptions.compressionOff,
    int maxMessageSize = 16 * 1024 * 1024,
  }) async {
    if (request is! RustHttpRequest) {
      return WebSocketTransformer.upgrade(
        request,
        protocolSelector: protocol == null ? protocolSelector : (_) => protocol,
        compression: compression,
      );
    }
    if (!request.isWebSocketUpgrade) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      throw const WebSocketException('Invalid WebSocket upgrade request');
    }
    if (protocol == null && protocolSelector != null) {
      final offered = _offeredProtocols(request);
      if (offered.isNotEmpty) {
        final selected = await protocolSelector(offered);
        protocol = selected?.toString();
      }
    }
    if (protocol != null) checkHeaderValue(protocol);
    final host = request.webSocketHost;
    final socket = RustWebSocket._(host, host.nextWebSocketId(), protocol);
    host.registerWebSocket(socket._id, socket);
    request.response.markUpgraded();
    final body = ByteData(16)
      ..setUint64(0, socket._id, Endian.little)
      ..setUint64(8, maxMessageSize, Endian.little);
    host.sendWebSocketRecord(
      request.id,
      OutboundKind.webSocketAccept,
      HttpStatus.switchingProtocols,
      body.buffer.asUint8List(),
      protocol: protocol,
    );
    return socket;
  }

  /// The subprotocols in the client's `sec-websocket-protocol` headers.
  static List<String> _offeredProtocols(HttpRequest request) => [
    for (final header
        in request.headers['sec-websocket-protocol'] ?? const <String>[])
      for (final name in header.split(','))
        if (name.trim().isNotEmpty) name.trim(),
  ];

  final WebSocketHost _host;
  final int _id;
  final StreamController<dynamic> _messages = StreamController<dynamic>();
  final Completer<void> _done = Completer<void>();
  int _state = WebSocket.open;
  int? _closeCode;
  String? _closeReason;

  @override
  final String? protocol;

  /// Always empty: no extension is agreed.
  @override
  String get extensions => '';

  @override
  int get readyState => _state;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  Duration? _pingInterval;

  @override
  Duration? get pingInterval => _pingInterval;

  @override
  set pingInterval(Duration? value) {
    _pingInterval = value;
    final milliseconds =
        value?.inMilliseconds.clamp(1, 0x7fffffffffffffff) ?? 0;
    final body = ByteData(8)..setUint64(0, milliseconds, Endian.little);
    _send(OutboundKind.webSocketPingInterval, body.buffer.asUint8List());
  }

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _messages.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Sends a [String] as text and a `List<int>` as binary. Dropped once
  /// the socket is closing.
  @override
  void add(dynamic data) {
    switch (data) {
      case final String text:
        _send(OutboundKind.webSocketText, utf8.encode(text));
      case final List<int> bytes:
        _send(OutboundKind.webSocketBinary, bytes);
      default:
        throw ArgumentError.value(data, 'data', 'must be String or List<int>');
    }
  }

  @override
  void addUtf8Text(List<int> bytes) => _send(OutboundKind.webSocketText, bytes);

  /// Errors are not sent to the client, like dart:io.
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final Object? data in stream) {
      add(data);
    }
  }

  /// Starts the close handshake with [code] and [reason].
  @override
  Future<void> close([int? code, String? reason]) {
    if (_isReserved(code)) {
      throw WebSocketException('Reserved status code $code');
    }
    final text = utf8.encode(reason ?? '');
    if (text.length > 123) {
      throw const WebSocketException('Reason is longer than 123 bytes');
    }
    if (_state == WebSocket.open) {
      _state = WebSocket.closing;
      _host.sendWebSocketRecord(
        _id,
        OutboundKind.webSocketClose,
        code ?? 0,
        text,
      );
    }
    // Like dart:io, the future completes once our close frame is on its
    // way, not when the peer answers it: [done] reports the end.
    return Future<void>.value();
  }

  @override
  Future<void> get done => _done.future;

  @override
  void receive(InboundKind kind, int closeCode, List<int> payload) {
    switch (kind) {
      case InboundKind.webSocketText:
        _messages.add(utf8.decode(payload));
      case InboundKind.webSocketBinary:
        _messages.add(Uint8List.fromList(payload));
      default:
        _closed(closeCode, utf8.decode(payload, allowMalformed: true));
    }
  }

  @override
  void serverClosed() => _closed(WebSocketStatus.abnormalClosure, '');

  void _send(OutboundKind kind, List<int> data) {
    if (_state != WebSocket.open) return;
    _host.sendWebSocketRecord(_id, kind, 0, data);
  }

  void _closed(int code, String reason) {
    if (_state == WebSocket.closed) return;
    _state = WebSocket.closed;
    _closeCode = code;
    _closeReason = reason;
    _host.unregisterWebSocket(_id);
    // Not awaited: without a listener the close future never completes.
    unawaited(_messages.close());
    _done.complete();
  }

  /// Codes a server may not send, like dart:io.
  static bool _isReserved(int? code) =>
      code != null &&
      (code < WebSocketStatus.normalClosure ||
          code == WebSocketStatus.reserved1004 ||
          code == WebSocketStatus.noStatusReceived ||
          code == WebSocketStatus.abnormalClosure ||
          (code > WebSocketStatus.internalServerError && code < 3000) ||
          code > 4999);
}

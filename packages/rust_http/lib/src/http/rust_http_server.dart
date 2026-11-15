import 'dart:async';
import 'dart:ffi' show NativePort;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../engine/ffi_http_engine.dart';
import '../engine/http_engine.dart';
import '../engine/pump_scheduler.dart';
import '../ffi/native_library.dart';
import '../protocol/inbound_record.dart';
import '../protocol/kinds.dart';
import '../protocol/outbound_record_writer.dart';
import '../websocket/websocket_host.dart';
import 'answer_channel.dart';
import 'compression_policy.dart';
import 'headers/header_validation.dart';
import 'headers/response_headers.dart';
import 'response/header_line_encoder.dart';
import 'rust_http_request.dart';

/// An [HttpServer] where Rust owns the sockets and parses HTTP, on the
/// thread of this isolate. Handlers run in Dart, like with `dart:io`.
///
/// ```dart
/// final server = await RustHttpServer.bind(3000);
/// server.listen((request) {
///   request.response.write('Hello World');
///   request.response.close();
/// });
/// ```
///
/// Each isolate can bind the same port; the OS spreads connections over
/// them.
final class RustHttpServer extends Stream<HttpRequest>
    implements HttpServer, AnswerChannel, WebSocketHost {
  RustHttpServer._(HttpEngine engine, this.address, this._receivePort)
    : _writer = OutboundRecordWriter(engine.newOutboundBuffer()),
      _reader = InboundBatchReader(engine.externalBodies) {
    _encoder = HeaderLineEncoder(defaultResponseHeaders);
    _scheduler = PumpScheduler(_pump);
  }

  /// Whether the native library is loaded and works.
  static bool get isAvailable => nativeLibrary.status is NativeLibraryLoaded;

  /// Why [isAvailable] is false, or null.
  static String? get loadError => switch (nativeLibrary.status) {
    NativeLibraryUnavailable(:final reason) => reason,
    NativeLibraryLoaded() => null,
  };

  /// Throws an [UnsupportedError] that says why the native library did not
  /// load and how to fix it. Does nothing when it loaded.
  static void ensureAvailable() => nativeLibrary.ensureAvailable();

  /// Listens on [port].
  ///
  /// With no [address] it listens on all interfaces (IPv6 and IPv4).
  /// [address] is an [InternetAddress] or a host name, like
  /// `HttpServer.bind`.
  ///
  /// - Bodies over [maxBodySize] bytes get 413; a `multipart/form-data`
  ///   body may be up to [maxMultipartSize] (default [maxBodySize]).
  /// - A client that sends no body bytes for [bodyTimeout] gets 408.
  /// - With [maxConnections], at most that many connections are open;
  ///   more clients wait in the OS listen queue.
  /// - A keep-alive connection with no request for [idleTimeout] closes.
  ///   Behind a load balancer, set it above the balancer's idle timeout.
  /// - [shared] exists for `HttpServer.bind` compatibility: isolates can
  ///   always share a port.
  static Future<RustHttpServer> bind(
    int port, {
    Object? address,
    int maxBodySize = 100 * 1024 * 1024,
    int? maxMultipartSize,
    Duration bodyTimeout = const Duration(seconds: 120),
    int? maxConnections,
    Duration idleTimeout = const Duration(seconds: 30),
    bool shared = false,
  }) async {
    ensureAvailable();
    if (port < 0 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'must be 0 to 65535');
    }
    if (maxConnections != null && maxConnections < 1) {
      throw ArgumentError.value(
        maxConnections,
        'maxConnections',
        'must be 1 or more',
      );
    }
    if (idleTimeout <= Duration.zero) {
      throw ArgumentError.value(
        idleTimeout,
        'idleTimeout',
        'must be more than zero',
      );
    }
    final ip = await _resolve(address);
    late final RustHttpServer server;
    final receivePort = RawReceivePort((Object? message) {
      // An empty message is the native side's "is this isolate alive?".
      if (message is! Uint8List || message.isEmpty) return;
      if (message.first == EngineSignal.drained) return server._drained();
      server._pump();
    }, 'rust_http');
    const engine = FfiHttpEngine();
    final EngineServer native;
    try {
      native = engine.bind(
        BindConfig(
          port: port,
          address: ip,
          maxBodySize: maxBodySize,
          maxMultipartSize: maxMultipartSize ?? maxBodySize,
          bodyTimeout: bodyTimeout,
          maxConnections: maxConnections,
          idleTimeout: idleTimeout,
        ),
        receivePort.sendPort.nativePort,
      );
    } on Object {
      receivePort.close();
      rethrow;
    }
    server = RustHttpServer._(
      engine,
      ip ?? InternetAddress.anyIPv6,
      receivePort,
    ).._native = native;
    // ignore: deprecated_member_use_from_same_package
    server.idleTimeout = idleTimeout;
    return server;
  }

  /// Null for all interfaces; a host name resolves to its first address.
  static Future<InternetAddress?> _resolve(Object? address) async {
    if (address == null) return null;
    if (address is InternetAddress) return address;
    final host = address.toString();
    return InternetAddress.tryParse(host) ??
        (await InternetAddress.lookup(host)).first;
  }

  final RawReceivePort _receivePort;
  final OutboundRecordWriter _writer;
  final InboundBatchReader _reader;
  late final HeaderLineEncoder _encoder;
  late final PumpScheduler _scheduler;
  EngineServer? _native;

  final StreamController<HttpRequest> _requests = StreamController<HttpRequest>(
    sync: true,
  );
  final Map<int, WebSocketReceiver> _sockets = {};
  final Map<int, StreamListener> _streams = {};
  final List<RustHttpRequest> _batch = [];
  int _nextSocketId = 1;
  int _nextStreamId = 1;

  /// Requests given to the app and not answered yet.
  int _open = 0;
  bool _inBatch = false;
  bool _lastPumpEmpty = true;
  Completer<void>? _draining;

  /// How long a pump may wait for requests, when none is open and the last
  /// pump found nothing; else Dart may have other work and must not wait.
  static const Duration _idleBudget = Duration(microseconds: 1000);

  @override
  late final int port = _native!.port;

  @override
  int get localPort => port;

  @override
  final InternetAddress address;

  @override
  bool autoCompress = false;

  /// The idle timeout given to [bind]. Setting it later has no effect: Rust
  /// reads it once, at bind. It stays so code that sets it compiles.
  @Deprecated('Setting it has no effect. Pass idleTimeout to bind.')
  @override
  Duration? idleTimeout = const Duration(seconds: 30);

  @override
  String? get serverHeader => _encoder.serverHeader;

  @override
  set serverHeader(String? value) =>
      _encoder.serverHeader = value == null ? null : checkHeaderValue(value);

  @override
  set sessionTimeout(int timeout) {}

  /// The same defaults as dart:io.
  @override
  final ResponseHeaders defaultResponseHeaders = ResponseHeaders.empty()
    ..set(HttpHeaders.contentTypeHeader, 'text/plain; charset=utf-8')
    ..set('x-frame-options', 'SAMEORIGIN')
    ..set('x-content-type-options', 'nosniff')
    ..set('x-xss-protection', '1; mode=block');

  @override
  bool get isOpen => _native != null;

  @override
  HttpConnectionsInfo connectionsInfo() => HttpConnectionsInfo();

  @override
  StreamSubscription<HttpRequest> listen(
    void Function(HttpRequest event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _requests.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Stops listening. Like dart:io, open requests still get their answer:
  /// each connection closes after its current answer, and the future
  /// completes when all are closed. With [force] every connection closes
  /// at once, also while a graceful close waits.
  @override
  Future<void> close({bool force = false}) async {
    final native = _native;
    if (native == null) return;
    if (!force) {
      var draining = _draining;
      if (draining == null) {
        draining = _draining = Completer<void>();
        native.shutdown();
        _scheduler.schedule();
      }
      await draining.future;
    }
    _release();
  }

  void _release() {
    final native = _native;
    if (native == null) return;
    _native = null;
    _scheduler.stop();
    native.unbind();
    _receivePort.close();
    // Not awaited: without a listener the close future never completes.
    unawaited(_requests.close());
    for (final socket in List.of(_sockets.values)) {
      socket.serverClosed();
    }
    for (final stream in List.of(_streams.values)) {
      stream.onClientGone();
    }
    _streams.clear();
    _drained();
  }

  void _drained() {
    final draining = _draining;
    if (draining != null && !draining.isCompleted) draining.complete();
  }

  // ---- engine pump ------------------------------------------------------

  /// Sends the queued records and takes the next batch, in one call.
  void _pump() {
    final native = _native;
    if (native == null) return;
    final budget = _open <= 0 && _lastPumpEmpty ? _idleBudget : Duration.zero;
    final batch = native.run(_writer.buffer, _writer.length, budget);
    _writer.reset();
    _lastPumpEmpty = batch == null;
    if (batch == null) {
      _scheduler.idle();
      return; // The engine posts to the port when more comes.
    }
    _onBatch(batch.bytes);
  }

  void _onBatch(List<int> bytes) {
    final batch = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    var webSocketBytes = 0;
    _inBatch = true;
    try {
      for (final record in _reader.read(batch)) {
        switch (record) {
          case RequestRecord():
            _open++;
            final request = RustHttpRequest(this, this, record);
            _batch.add(request);
            _requests.add(request);
          case StreamProgressRecord(:final id, :final sentBytes):
            final stream = sentBytes == null
                ? _streams.remove(id)
                : _streams[id];
            if (sentBytes == null) {
              stream?.onClientGone();
            } else {
              stream?.onSent(sentBytes);
            }
          case WebSocketRecord(:final id, :final kind, :final closeCode):
            if (kind != InboundKind.webSocketClosed) {
              webSocketBytes += record.payload.length;
            }
            _sockets[id]?.receive(kind, closeCode, record.payload);
        }
      }
    } finally {
      // A request still open after its batch (an async handler or a
      // stream) gets its own copy of its bytes, so it does not keep the
      // batch alive. An upgrade counts as answered, but apps often keep its
      // request for the socket's life, so it gets a copy too.
      for (final request in _batch) {
        if (!request.isAnswered || request.isWebSocketUpgrade) {
          request.detach(batch);
        }
      }
      _batch.clear();
      // Rust stops reading frames while Dart is too far behind.
      if (webSocketBytes > 0) {
        sendWebSocketRecord(
          webSocketBytes,
          OutboundKind.webSocketAck,
          0,
          const <int>[],
        );
      }
      _inBatch = false;
      // More may wait: always ask again.
      _scheduler.schedule();
    }
  }

  void _queued() {
    if (!_inBatch) _scheduler.schedule();
  }

  int _start(int id, int status, OutboundKind kind, {int flags = 0}) {
    if (kind.answersRequest) _open--;
    return _writer.start(id, status, kind, flags: flags);
  }

  // ---- AnswerChannel ----------------------------------------------------

  @override
  void sendAnswer(AnswerSource source) {
    if (!isOpen) return;
    final body = source.takeBody();
    final gzip =
        autoCompress &&
        CompressionPolicy.apply(
          acceptEncoding: source.acceptEncoding,
          response: source.headers,
          bodyLength: body.length,
        );
    final start = _start(
      source.requestId,
      source.statusCode,
      OutboundKind.answer,
      flags: gzip ? AnswerFlags.gzip : 0,
    );
    if (_encoder.write(_writer, source)) {
      _writer.addFlags(start, AnswerFlags.connectionClose);
    }
    _writer.finish(start, body);
    _queued();
  }

  @override
  int startStream(
    AnswerSource source,
    List<int> first,
    StreamListener listener,
  ) {
    final id = _nextStreamId++;
    if (!isOpen) return id;
    _streams[id] = listener;
    final start = _start(
      source.requestId,
      source.statusCode,
      OutboundKind.streamStart,
    );
    // Rust drops the length of a whole body; for a stream it is the only
    // way the client learns the length up front.
    if (_encoder.write(_writer, source, withLength: true)) {
      _writer.addFlags(start, AnswerFlags.connectionClose);
    }
    _writer.finish(start, first, prefix: id);
    _queued();
    return id;
  }

  @override
  void sendStreamPart(int streamId, List<int> data) {
    if (!isOpen || data.isEmpty) return;
    _writer.finish(_start(streamId, 0, OutboundKind.streamPart), data);
    _queued();
  }

  @override
  void endStream(int streamId, {required bool complete}) {
    _streams.remove(streamId);
    if (!isOpen) return;
    final status = complete ? 0 : 1;
    _writer.finish(
      _start(streamId, status, OutboundKind.streamEnd),
      const <int>[],
    );
    _queued();
  }

  // ---- WebSocketHost ----------------------------------------------------

  @override
  int nextWebSocketId() => _nextSocketId++;

  @override
  void registerWebSocket(int id, WebSocketReceiver socket) =>
      _sockets[id] = socket;

  @override
  void unregisterWebSocket(int id) => _sockets.remove(id);

  @override
  void sendWebSocketRecord(
    int id,
    OutboundKind kind,
    int status,
    List<int> body, {
    String? protocol,
  }) {
    if (!isOpen) return;
    final start = _start(id, status, kind);
    if (protocol != null)
      _writer.headerLine('sec-websocket-protocol', protocol);
    _writer.finish(start, body);
    _queued();
  }
}

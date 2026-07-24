import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';

import 'rpc_websocket_protocol.dart';

typedef RpcWebSocketConnectionAuthorizer =
    FutureOr<void> Function(RpcContext context);

final class RpcWebSocketServerOptions {
  const RpcWebSocketServerOptions({
    this.path = '/rpc/ws',
    this.maxFrameBytes = 1024 * 1024,
    this.maxActiveCallsPerConnection = 128,
    this.maxBufferedFramesPerCall = 64,
    this.maxBufferedBytesPerCall = 1024 * 1024,
    this.maxBufferedFramesPerConnection = 512,
    this.maxBufferedBytesPerConnection = 8 * 1024 * 1024,
    this.maxConnections = 10000,
    this.pingInterval = const Duration(seconds: 30),
    this.authorize,
  }) : assert(maxFrameBytes > 0),
       assert(maxActiveCallsPerConnection > 0),
       assert(maxBufferedFramesPerCall > 0),
       assert(maxBufferedBytesPerCall > 0),
       assert(maxBufferedFramesPerConnection > 0),
       assert(maxBufferedBytesPerConnection > 0),
       assert(maxConnections > 0);

  final String path;
  final int maxFrameBytes;
  final int maxActiveCallsPerConnection;
  final int maxBufferedFramesPerCall;
  final int maxBufferedBytesPerCall;
  final int maxBufferedFramesPerConnection;
  final int maxBufferedBytesPerConnection;
  final int maxConnections;
  final Duration pingInterval;
  final RpcWebSocketConnectionAuthorizer? authorize;
}

final class RpcWebSocketUpgradeHandler implements RpcHttpUpgradeHandler {
  RpcWebSocketUpgradeHandler({
    required this.procedures,
    this.options = const RpcWebSocketServerOptions(),
  }) : _codec = RpcWebSocketFrameCodec(maxFrameBytes: options.maxFrameBytes);

  final RpcProcedureRegistry procedures;
  final RpcWebSocketServerOptions options;
  final RpcWebSocketFrameCodec _codec;
  final Set<_RpcWebSocketConnection> _connections = {};
  bool _accepting = true;

  int get activeConnections => _connections.length;

  @override
  bool canHandle(HttpRequest request) {
    return _normalizePath(request.uri.path) == _normalizePath(options.path) &&
        WebSocketTransformer.isUpgradeRequest(request);
  }

  @override
  Future<void> handle(HttpRequest request, RpcContext context) async {
    if (!_accepting) {
      await _reject(request, HttpStatus.serviceUnavailable, 'Server draining.');
      return;
    }
    if (_connections.length >= options.maxConnections) {
      await _reject(
        request,
        HttpStatus.serviceUnavailable,
        'WebSocket connection limit reached.',
      );
      return;
    }

    final requestedProtocols = request.headers
        .value('sec-websocket-protocol')
        ?.split(',')
        .map((value) => value.trim())
        .toSet();
    if (requestedProtocols == null ||
        !requestedProtocols.contains(rpcWebSocketSubprotocol)) {
      await _reject(
        request,
        HttpStatus.upgradeRequired,
        'WebSocket subprotocol $rpcWebSocketSubprotocol is required.',
      );
      return;
    }

    try {
      await options.authorize?.call(context);
    } on RpcException catch (error) {
      await _reject(request, error.statusCode, error.message, code: error.code);
      return;
    }

    final socket = await WebSocketTransformer.upgrade(
      request,
      protocolSelector: (protocols) =>
          protocols.contains(rpcWebSocketSubprotocol)
          ? rpcWebSocketSubprotocol
          : null,
    );
    socket.pingInterval = options.pingInterval;

    final connection = _RpcWebSocketConnection(
      socket: socket,
      procedures: procedures,
      baseContext: context,
      codec: _codec,
      options: options,
    );
    _connections.add(connection);
    try {
      await connection.run();
    } finally {
      _connections.remove(connection);
    }
  }

  @override
  Future<void> close({required Duration gracePeriod}) async {
    _accepting = false;
    if (_connections.isEmpty) {
      return;
    }
    final connections = _connections.toList(growable: false);
    for (final connection in connections) {
      connection.beginDrain();
    }

    if (gracePeriod > Duration.zero) {
      final drained = await Future.any([
        Future.wait([
          for (final connection in connections) connection.done,
        ]).then((_) => true),
        Future<void>.delayed(gracePeriod).then((_) => false),
      ]);
      if (drained) {
        return;
      }
    }

    await Future.wait([
      for (final connection in _connections.toList(growable: false))
        connection.close(WebSocketStatus.goingAway, 'Server shutting down.'),
    ]);
  }

  static Future<void> _reject(
    HttpRequest request,
    int statusCode,
    String message, {
    RpcErrorCode? code,
  }) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode(
          RpcException(
            code:
                code ??
                (statusCode == HttpStatus.serviceUnavailable
                    ? RpcErrorCode.resourceExhausted
                    : RpcErrorCode.badRequest),
            message: message,
          ).toResponse().toJson(),
        ),
      );
    await request.response.close();
  }
}

final class _RpcWebSocketConnection {
  _RpcWebSocketConnection({
    required this.socket,
    required this.procedures,
    required this.baseContext,
    required this.codec,
    required this.options,
  }) : _writer = _BoundedWebSocketWriter(
         socket: socket,
         codec: codec,
         options: options,
       );

  final WebSocket socket;
  final RpcProcedureRegistry procedures;
  final RpcContext baseContext;
  final RpcWebSocketFrameCodec codec;
  final RpcWebSocketServerOptions options;
  final _BoundedWebSocketWriter _writer;
  final Map<String, _ActiveServerCall> _calls = {};
  final Completer<void> _done = Completer<void>();
  StreamSubscription<Object?>? _incoming;
  bool _closed = false;
  bool _acceptingCalls = true;

  Future<void> get done => _done.future;

  Future<void> run() async {
    _incoming = socket.listen(
      _onMessage,
      onError: (_, _) => unawaited(_terminate()),
      onDone: () => unawaited(_terminate()),
      cancelOnError: true,
    );
    await done;
  }

  void _onMessage(Object? message) {
    if (_closed) {
      return;
    }
    final RpcWebSocketFrame frame;
    try {
      frame = codec.decode(message);
    } on RpcWebSocketProtocolException catch (error) {
      unawaited(close(WebSocketStatus.protocolError, error.message));
      return;
    }

    switch (frame) {
      case RpcWebSocketCallFrame():
        _start(frame);
      case RpcWebSocketCancelFrame(:final id):
        unawaited(_cancel(id));
      default:
        unawaited(
          close(
            WebSocketStatus.protocolError,
            'Client sent a server-only frame.',
          ),
        );
    }
  }

  void _start(RpcWebSocketCallFrame frame) {
    if (!_acceptingCalls) {
      _sendError(frame.id, RpcException.cancelled('Server is shutting down.'));
      return;
    }
    if (_calls.containsKey(frame.id)) {
      _rejectDuplicate(frame.id);
      return;
    }
    if (_calls.length >= options.maxActiveCallsPerConnection) {
      _sendError(
        frame.id,
        RpcException.resourceExhausted(
          'The WebSocket connection has too many active RPC calls.',
        ),
      );
      return;
    }

    final call = _ActiveServerCall();
    _calls[frame.id] = call;
    final context = baseContext.copyWith(
      cancellation: call.cancellation.signal,
    );
    final request = RpcRequest(method: frame.method, input: frame.input);

    switch (frame.kind) {
      case RpcWebSocketCallKind.unary:
        unawaited(_runUnary(frame.id, context, request));
      case RpcWebSocketCallKind.stream:
        _runStream(frame.id, call, context, request);
    }
  }

  void _rejectDuplicate(String id) {
    final existing = _calls.remove(id);
    existing?.cancellation.cancel();
    unawaited(_cancelSubscription(existing?.subscription));
    _sendError(
      id,
      RpcException.conflict('RPC call id "$id" is already active.'),
    );
  }

  Future<void> _runUnary(
    String id,
    RpcContext context,
    RpcRequest request,
  ) async {
    try {
      final result = await procedures.dispatchUnary(context, request);
      if (_calls.containsKey(id) && !context.cancellation.isCancelled) {
        if (!_send(id, RpcWebSocketResultFrame(id: id, data: result))) {
          _sendError(
            id,
            RpcException.resourceExhausted(
              'RPC result exceeded the configured WebSocket buffer limit.',
            ),
          );
        }
      }
    } on Object catch (error) {
      if (_calls.containsKey(id)) {
        _sendError(id, _asRpcException(error));
      }
    } finally {
      _calls.remove(id);
    }
  }

  void _runStream(
    String id,
    _ActiveServerCall call,
    RpcContext context,
    RpcRequest request,
  ) {
    call.subscription = procedures
        .dispatchStream(context, request)
        .listen(
          (event) {
            if (!_send(id, RpcWebSocketNextFrame(id: id, data: event))) {
              unawaited(_overflow(id));
              return;
            }
            if (_writer.isConnectionAtCapacity) {
              final drained = _writer.whenConnectionDrained;
              for (final activeCall in _calls.values) {
                activeCall.subscription?.pause(drained);
              }
            } else if (_writer.isCallAtCapacity(id)) {
              call.subscription?.pause(_writer.whenCallDrained(id));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_calls.containsKey(id)) {
              _sendError(id, _asRpcException(error));
              unawaited(_finish(id));
            }
          },
          onDone: () {
            if (_calls.containsKey(id)) {
              if (!_send(id, RpcWebSocketCompleteFrame(id))) {
                _sendError(
                  id,
                  RpcException.resourceExhausted(
                    'RPC completion exceeded the configured WebSocket buffer limit.',
                  ),
                );
              }
              unawaited(_finish(id));
            }
          },
          cancelOnError: false,
        );
  }

  bool _send(String id, RpcWebSocketFrame frame) {
    return _writer.enqueue(id, frame);
  }

  void _sendError(String id, RpcException error) {
    final queued = _writer.enqueue(
      id,
      RpcWebSocketErrorFrame(
        id: id,
        error: RpcErrorBody(code: error.code.wireName, message: error.message),
      ),
      bypassCallLimit: true,
    );
    if (!queued) {
      unawaited(
        close(
          WebSocketStatus.policyViolation,
          'WebSocket output buffer exhausted.',
        ),
      );
    }
  }

  Future<void> _overflow(String id) async {
    final call = _calls[id];
    if (call == null) {
      return;
    }
    call.cancellation.cancel();
    await _cancelSubscription(call.subscription);
    _sendError(
      id,
      RpcException.resourceExhausted(
        'RPC stream output exceeded the configured buffer limit.',
      ),
    );
    _calls.remove(id);
  }

  Future<void> _cancel(String id) async {
    final call = _calls.remove(id);
    if (call == null) {
      return;
    }
    call.cancellation.cancel();
    await _cancelSubscription(call.subscription);
  }

  Future<void> _finish(String id) async {
    final call = _calls.remove(id);
    call?.cancellation.cancel();
    await _cancelSubscription(call?.subscription);
  }

  void beginDrain() {
    _acceptingCalls = false;
  }

  Future<void> close(int code, String reason) async {
    if (_closed) {
      return done;
    }
    _closed = true;
    await _incoming?.cancel();
    for (final call in _calls.values.toList(growable: false)) {
      call.cancellation.cancel();
      await _cancelSubscription(call.subscription);
    }
    _calls.clear();
    await _writer.close(code, reason);
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  Future<void> _terminate() async {
    if (_closed) {
      if (!_done.isCompleted) {
        _done.complete();
      }
      return;
    }
    _closed = true;
    for (final call in _calls.values.toList(growable: false)) {
      call.cancellation.cancel();
      await _cancelSubscription(call.subscription);
    }
    _calls.clear();
    _writer.dispose();
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  static RpcException _asRpcException(Object error) {
    return error is RpcException ? error : RpcException.internalError();
  }

  static Future<void> _cancelSubscription(
    StreamSubscription<Object?>? subscription,
  ) async {
    try {
      subscription?.resume();
      await subscription?.cancel();
    } on RpcException catch (error) {
      if (error.code != RpcErrorCode.cancelled) {
        rethrow;
      }
    }
  }
}

final class _ActiveServerCall {
  final RpcCancellationSource cancellation = RpcCancellationSource();
  StreamSubscription<Object?>? subscription;
}

final class _BoundedWebSocketWriter {
  _BoundedWebSocketWriter({
    required this.socket,
    required this.codec,
    required this.options,
  });

  final WebSocket socket;
  final RpcWebSocketFrameCodec codec;
  final RpcWebSocketServerOptions options;
  final Queue<_QueuedFrame> _queue = Queue<_QueuedFrame>();
  final Map<String, int> _callFrames = {};
  final Map<String, int> _callBytes = {};
  final Map<String, Completer<void>> _callDrained = {};
  Completer<void>? _connectionDrained;
  var _connectionBytes = 0;
  var _draining = false;
  var _closed = false;

  bool enqueue(
    String callId,
    RpcWebSocketFrame frame, {
    bool bypassCallLimit = false,
  }) {
    if (_closed) {
      return false;
    }
    final encoded = codec.encode(frame);
    final bytes = utf8.encode(encoded).length;
    final callFrames = _callFrames[callId] ?? 0;
    final callBytes = _callBytes[callId] ?? 0;
    if (!bypassCallLimit &&
        (callFrames >= options.maxBufferedFramesPerCall ||
            callBytes + bytes > options.maxBufferedBytesPerCall)) {
      return false;
    }
    if (_queue.length >= options.maxBufferedFramesPerConnection ||
        _connectionBytes + bytes > options.maxBufferedBytesPerConnection) {
      return false;
    }

    _queue.add(_QueuedFrame(callId, encoded, bytes));
    _callFrames[callId] = callFrames + 1;
    _callBytes[callId] = callBytes + bytes;
    _connectionBytes += bytes;
    _callDrained.putIfAbsent(callId, Completer<void>.new);
    _connectionDrained ??= Completer<void>();
    if (!_draining) {
      unawaited(_drain());
    }
    return true;
  }

  Future<void> whenCallDrained(String callId) {
    if (!_callFrames.containsKey(callId)) {
      return Future<void>.value();
    }
    return (_callDrained[callId] ??= Completer<void>()).future;
  }

  bool isCallAtCapacity(String callId) {
    return (_callFrames[callId] ?? 0) >= options.maxBufferedFramesPerCall ||
        (_callBytes[callId] ?? 0) >= options.maxBufferedBytesPerCall;
  }

  bool get isConnectionAtCapacity =>
      _queue.length >= options.maxBufferedFramesPerConnection ||
      _connectionBytes >= options.maxBufferedBytesPerConnection;

  Future<void> get whenConnectionDrained =>
      _connectionDrained?.future ?? Future<void>.value();

  Future<void> _drain() async {
    _draining = true;
    try {
      while (!_closed && _queue.isNotEmpty) {
        final item = _queue.removeFirst();
        try {
          await socket.addStream(Stream<Object>.value(item.payload));
        } finally {
          _connectionBytes -= item.bytes;
          _decrement(_callFrames, item.callId, 1);
          _decrement(_callBytes, item.callId, item.bytes);
          if (!_callFrames.containsKey(item.callId)) {
            _callDrained.remove(item.callId)?.complete();
          }
          if (_queue.isEmpty && _connectionBytes == 0) {
            _connectionDrained?.complete();
            _connectionDrained = null;
          }
        }
      }
    } on Object {
      dispose();
    } finally {
      _draining = false;
    }
  }

  Future<void> close(int code, String reason) async {
    if (_closed) {
      return;
    }
    while (_draining || _queue.isNotEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    _closed = true;
    await socket.close(code, reason);
  }

  void dispose() {
    _closed = true;
    _queue.clear();
    _callFrames.clear();
    _callBytes.clear();
    for (final signal in _callDrained.values) {
      if (!signal.isCompleted) {
        signal.complete();
      }
    }
    _callDrained.clear();
    if (!(_connectionDrained?.isCompleted ?? true)) {
      _connectionDrained?.complete();
    }
    _connectionDrained = null;
    _connectionBytes = 0;
  }

  static void _decrement(Map<String, int> values, String key, int amount) {
    final next = (values[key] ?? 0) - amount;
    if (next <= 0) {
      values.remove(key);
    } else {
      values[key] = next;
    }
  }
}

final class _QueuedFrame {
  const _QueuedFrame(this.callId, this.payload, this.bytes);

  final String callId;
  final String payload;
  final int bytes;
}

String _normalizePath(String path) {
  if (path.isEmpty) {
    return '/';
  }
  final normalized = path.startsWith('/') ? path : '/$path';
  if (normalized.length > 1 && normalized.endsWith('/')) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

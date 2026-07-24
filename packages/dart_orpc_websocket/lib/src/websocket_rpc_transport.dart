import 'dart:async';
import 'dart:io';

import 'package:dart_orpc_client/dart_orpc_client.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_websocket_protocol.dart';

final class WebSocketRpcTransport implements RpcDuplexTransport {
  WebSocketRpcTransport._({
    required WebSocket socket,
    required RpcWebSocketFrameCodec codec,
  }) : _socket = socket,
       _codec = codec {
    _incoming = _socket.listen(
      _onMessage,
      onError: (Object error, StackTrace stackTrace) {
        _closed = true;
        _failAll(RpcClientException('WebSocket connection failed: $error'));
      },
      onDone: () {
        _closed = true;
        _failAll(const RpcClientException('WebSocket connection closed.'));
      },
      cancelOnError: true,
    );
  }

  static Future<WebSocketRpcTransport> connect(
    Uri uri, {
    int maxFrameBytes = 1024 * 1024,
    Map<String, Object?> headers = const {},
  }) async {
    final WebSocket socket;
    try {
      socket = await WebSocket.connect(
        uri.toString(),
        protocols: const [rpcWebSocketSubprotocol],
        headers: headers,
      );
    } on Object catch (error) {
      throw RpcClientException(
        'Failed to connect WebSocket RPC transport to $uri: $error',
      );
    }
    if (socket.protocol != rpcWebSocketSubprotocol) {
      await socket.close(
        WebSocketStatus.protocolError,
        'Unsupported WebSocket subprotocol.',
      );
      throw RpcClientException(
        'WebSocket server did not negotiate $rpcWebSocketSubprotocol.',
      );
    }
    return WebSocketRpcTransport._(
      socket: socket,
      codec: RpcWebSocketFrameCodec(maxFrameBytes: maxFrameBytes),
    );
  }

  final WebSocket _socket;
  final RpcWebSocketFrameCodec _codec;
  final Map<String, _PendingClientCall> _pending = {};
  late final StreamSubscription<Object?> _incoming;
  var _nextId = 0;
  var _closed = false;
  Future<void>? _closing;

  int get pendingCalls => _pending.length;

  @override
  Future<Object?> send(RpcRequest request) {
    if (_closed) {
      return Future<Object?>.error(
        const RpcClientException('WebSocket RPC transport is closed.'),
      );
    }
    final id = _allocateId();
    final completer = Completer<Object?>();
    _pending[id] = _PendingUnaryCall(completer);
    try {
      _sendFrame(
        RpcWebSocketCallFrame(
          id: id,
          kind: RpcWebSocketCallKind.unary,
          method: request.method,
          input: request.input,
        ),
      );
    } on Object catch (error) {
      _pending.remove(id);
      completer.completeError(_asClientException(error));
    }
    return completer.future;
  }

  @override
  Stream<Object?> subscribe(RpcRequest request) {
    late StreamController<Object?> controller;
    String? callId;
    controller = StreamController<Object?>(
      onListen: () {
        if (_closed) {
          controller.addError(
            const RpcClientException('WebSocket RPC transport is closed.'),
          );
          unawaited(controller.close());
          return;
        }
        final id = _allocateId();
        callId = id;
        _pending[id] = _PendingStreamCall(controller);
        try {
          _sendFrame(
            RpcWebSocketCallFrame(
              id: id,
              kind: RpcWebSocketCallKind.stream,
              method: request.method,
              input: request.input,
            ),
          );
        } on Object catch (error) {
          _pending.remove(id);
          controller.addError(_asClientException(error));
          unawaited(controller.close());
        }
      },
      onCancel: () {
        final id = callId;
        if (id != null && _pending.remove(id) != null && !_closed) {
          _sendFrame(RpcWebSocketCancelFrame(id));
        }
      },
    );
    return controller.stream;
  }

  void _onMessage(Object? message) {
    final RpcWebSocketFrame frame;
    try {
      frame = _codec.decode(message);
    } on Object catch (error) {
      _failAll(_asClientException(error));
      unawaited(
        close(
          code: WebSocketStatus.protocolError,
          reason: 'Invalid server frame.',
        ),
      );
      return;
    }

    switch (frame) {
      case RpcWebSocketResultFrame(:final id, :final data):
        final call = _pending[id];
        if (call is _PendingUnaryCall && !call.completer.isCompleted) {
          _pending.remove(id);
          call.completer.complete(data);
        } else {
          _protocolFailure('Unexpected result frame for call "$id".');
        }
      case RpcWebSocketNextFrame(:final id, :final data):
        final call = _pending[id];
        if (call is _PendingStreamCall && !call.controller.isClosed) {
          call.controller.add(data);
        } else {
          _protocolFailure('Unexpected next frame for call "$id".');
        }
      case RpcWebSocketCompleteFrame(:final id):
        final call = _pending[id];
        if (call is _PendingStreamCall) {
          _pending.remove(id);
          unawaited(call.controller.close());
        } else {
          _protocolFailure('Unexpected complete frame for call "$id".');
        }
      case RpcWebSocketErrorFrame(:final id, :final error):
        final call = _pending.remove(id);
        if (call == null) {
          _protocolFailure('Unexpected error frame for call "$id".');
          return;
        }
        final rpcCode = RpcErrorCode.tryParseWireName(error.code);
        final failure = rpcCode == null
            ? RpcClientException(
                'WebSocket RPC returned unknown error code "${error.code}".',
              )
            : RpcException(code: rpcCode, message: error.message);
        switch (call) {
          case _PendingUnaryCall(:final completer):
            if (!completer.isCompleted) {
              completer.completeError(failure);
            }
          case _PendingStreamCall(:final controller):
            controller.addError(failure);
            unawaited(controller.close());
        }
      default:
        _protocolFailure('Server sent a client-only frame.');
    }
  }

  void _protocolFailure(String message) {
    final error = RpcClientException(message);
    _failAll(error);
    unawaited(
      close(
        code: WebSocketStatus.protocolError,
        reason: 'Invalid server frame.',
      ),
    );
  }

  void _sendFrame(RpcWebSocketFrame frame) {
    if (_closed) {
      throw const RpcClientException('WebSocket RPC transport is closed.');
    }
    _socket.add(_codec.encode(frame));
  }

  String _allocateId() {
    _nextId++;
    return _nextId.toString();
  }

  Future<void> close({
    int code = WebSocketStatus.normalClosure,
    String reason = 'Client closed.',
  }) {
    return _closing ??= _close(code, reason);
  }

  Future<void> _close(int code, String reason) async {
    if (_closed) {
      return;
    }
    _closed = true;
    _failAll(const RpcClientException('WebSocket RPC transport is closed.'));
    await _incoming.cancel();
    await _socket.close(code, reason);
  }

  void _failAll(Object error) {
    final calls = _pending.values.toList(growable: false);
    _pending.clear();
    for (final call in calls) {
      switch (call) {
        case _PendingUnaryCall(:final completer):
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        case _PendingStreamCall(:final controller):
          if (!controller.isClosed) {
            controller.addError(error);
            unawaited(controller.close());
          }
      }
    }
  }

  static RpcClientException _asClientException(Object error) {
    return error is RpcClientException ? error : RpcClientException('$error');
  }
}

sealed class _PendingClientCall {
  const _PendingClientCall();
}

final class _PendingUnaryCall extends _PendingClientCall {
  const _PendingUnaryCall(this.completer);

  final Completer<Object?> completer;
}

final class _PendingStreamCall extends _PendingClientCall {
  const _PendingStreamCall(this.controller);

  final StreamController<Object?> controller;
}

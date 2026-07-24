import 'dart:convert';

import 'package:dart_orpc_core/dart_orpc_core.dart';

const String rpcWebSocketSubprotocol = 'dart-orpc.v1';

enum RpcWebSocketCallKind { unary, stream }

sealed class RpcWebSocketFrame {
  const RpcWebSocketFrame();

  JsonObject toJson();
}

final class RpcWebSocketCallFrame extends RpcWebSocketFrame {
  const RpcWebSocketCallFrame({
    required this.id,
    required this.kind,
    required this.method,
    this.input,
  });

  final String id;
  final RpcWebSocketCallKind kind;
  final String method;
  final Object? input;

  @override
  JsonObject toJson() => {
    'type': 'call',
    'id': id,
    'kind': kind.name,
    'method': method,
    'input': input,
  };
}

final class RpcWebSocketCancelFrame extends RpcWebSocketFrame {
  const RpcWebSocketCancelFrame(this.id);

  final String id;

  @override
  JsonObject toJson() => {'type': 'cancel', 'id': id};
}

final class RpcWebSocketResultFrame extends RpcWebSocketFrame {
  const RpcWebSocketResultFrame({required this.id, this.data});

  final String id;
  final Object? data;

  @override
  JsonObject toJson() => {'type': 'result', 'id': id, 'data': data};
}

final class RpcWebSocketNextFrame extends RpcWebSocketFrame {
  const RpcWebSocketNextFrame({required this.id, this.data});

  final String id;
  final Object? data;

  @override
  JsonObject toJson() => {'type': 'next', 'id': id, 'data': data};
}

final class RpcWebSocketCompleteFrame extends RpcWebSocketFrame {
  const RpcWebSocketCompleteFrame(this.id);

  final String id;

  @override
  JsonObject toJson() => {'type': 'complete', 'id': id};
}

final class RpcWebSocketErrorFrame extends RpcWebSocketFrame {
  const RpcWebSocketErrorFrame({required this.id, required this.error});

  final String id;
  final RpcErrorBody error;

  @override
  JsonObject toJson() => {'type': 'error', 'id': id, 'error': error.toJson()};
}

final class RpcWebSocketProtocolException implements Exception {
  const RpcWebSocketProtocolException(this.message);

  final String message;

  @override
  String toString() => 'RpcWebSocketProtocolException: $message';
}

final class RpcWebSocketFrameCodec {
  const RpcWebSocketFrameCodec({this.maxFrameBytes = 1024 * 1024})
    : assert(maxFrameBytes > 0);

  final int maxFrameBytes;

  String encode(RpcWebSocketFrame frame) {
    final encoded = jsonEncode(frame.toJson());
    if (utf8.encode(encoded).length > maxFrameBytes) {
      throw const RpcWebSocketProtocolException(
        'WebSocket frame exceeds the configured size limit.',
      );
    }
    return encoded;
  }

  RpcWebSocketFrame decode(Object? message) {
    if (message is! String) {
      throw const RpcWebSocketProtocolException(
        'WebSocket frames must be UTF-8 JSON text.',
      );
    }
    if (utf8.encode(message).length > maxFrameBytes) {
      throw const RpcWebSocketProtocolException(
        'WebSocket frame exceeds the configured size limit.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(message);
    } on FormatException {
      throw const RpcWebSocketProtocolException(
        'WebSocket frame must contain valid JSON.',
      );
    }

    final object = _object(decoded, 'WebSocket frame');
    final type = _string(object, 'type');
    return switch (type) {
      'call' => RpcWebSocketCallFrame(
        id: _id(object),
        kind: _callKind(object),
        method: _nonEmptyString(object, 'method'),
        input: object['input'],
      ),
      'cancel' => RpcWebSocketCancelFrame(_id(object)),
      'result' => RpcWebSocketResultFrame(
        id: _id(object),
        data: object['data'],
      ),
      'next' => RpcWebSocketNextFrame(id: _id(object), data: object['data']),
      'complete' => RpcWebSocketCompleteFrame(_id(object)),
      'error' => RpcWebSocketErrorFrame(
        id: _id(object),
        error: _errorBody(object),
      ),
      _ => throw RpcWebSocketProtocolException(
        'Unsupported WebSocket frame type "$type".',
      ),
    };
  }

  static RpcWebSocketCallKind _callKind(JsonObject object) {
    final value = _string(object, 'kind');
    return switch (value) {
      'unary' => RpcWebSocketCallKind.unary,
      'stream' => RpcWebSocketCallKind.stream,
      _ => throw RpcWebSocketProtocolException(
        'Unsupported RPC call kind "$value".',
      ),
    };
  }

  static RpcErrorBody _errorBody(JsonObject object) {
    final error = _object(object['error'], 'WebSocket error');
    return RpcErrorBody(
      code: _nonEmptyString(error, 'code'),
      message: _nonEmptyString(error, 'message'),
    );
  }

  static String _id(JsonObject object) => _nonEmptyString(object, 'id');

  static String _nonEmptyString(JsonObject object, String field) {
    final value = _string(object, field);
    if (value.trim().isEmpty) {
      throw RpcWebSocketProtocolException(
        'WebSocket frame "$field" must be non-empty.',
      );
    }
    return value;
  }

  static String _string(JsonObject object, String field) {
    final value = object[field];
    if (value is! String) {
      throw RpcWebSocketProtocolException(
        'WebSocket frame "$field" must be a string.',
      );
    }
    return value;
  }

  static JsonObject _object(Object? value, String context) {
    if (value is! Map) {
      throw RpcWebSocketProtocolException('$context must be an object.');
    }
    return Map<String, Object?>.from(value);
  }
}

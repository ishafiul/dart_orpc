import 'dart:convert';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_websocket/dart_orpc_websocket.dart';
import 'package:test/test.dart';

void main() {
  group('Given the dart-orpc WebSocket frame codec', () {
    const codec = RpcWebSocketFrameCodec();
    final frames = <RpcWebSocketFrame>[
      const RpcWebSocketCallFrame(
        id: '1',
        kind: RpcWebSocketCallKind.unary,
        method: 'user.get',
        input: {'id': '1'},
      ),
      const RpcWebSocketCancelFrame('1'),
      const RpcWebSocketResultFrame(id: '1', data: {'id': '1'}),
      const RpcWebSocketNextFrame(id: '1', data: {'id': '1'}),
      const RpcWebSocketCompleteFrame('1'),
      const RpcWebSocketErrorFrame(
        id: '1',
        error: RpcErrorBody(code: 'NOT_FOUND', message: 'missing'),
      ),
    ];

    test('When valid frames round-trip then their JSON remains stable', () {
      for (final frame in frames) {
        final decoded = codec.decode(codec.encode(frame));
        expect(decoded.toJson(), frame.toJson());
      }
    });

    test('When extra fields are present then they are ignored', () {
      final decoded = codec.decode(
        jsonEncode({'type': 'cancel', 'id': '1', 'future-field': true}),
      );

      expect(decoded, isA<RpcWebSocketCancelFrame>());
    });

    for (final scenario in <(String, Object?)>[
      ('binary', <int>[1, 2]),
      ('invalid JSON', '{'),
      ('non-object JSON', '[]'),
      ('missing type', '{}'),
      ('non-string type', '{"type":1}'),
      ('empty id', '{"type":"cancel","id":""}'),
      ('non-string id', '{"type":"cancel","id":1}'),
      ('unknown type', '{"type":"unknown","id":"1"}'),
      ('missing call method', '{"type":"call","id":"1","kind":"unary"}'),
      (
        'empty call method',
        '{"type":"call","id":"1","kind":"unary","method":" "}',
      ),
      (
        'unknown call kind',
        '{"type":"call","id":"1","kind":"duplex","method":"x"}',
      ),
      ('non-object error', '{"type":"error","id":"1","error":"bad"}'),
      (
        'invalid error code',
        '{"type":"error","id":"1","error":{"code":"","message":"bad"}}',
      ),
      (
        'invalid error message',
        '{"type":"error","id":"1","error":{"code":"BAD_REQUEST","message":1}}',
      ),
    ]) {
      test('When ${scenario.$1} is decoded then it rejects the frame', () {
        expect(
          () => codec.decode(scenario.$2),
          throwsA(isA<RpcWebSocketProtocolException>()),
        );
      });
    }

    test('When a frame exceeds the limit then it is rejected', () {
      const limitedCodec = RpcWebSocketFrameCodec(maxFrameBytes: 32);

      expect(
        () => limitedCodec.decode('{"type":"cancel","id":"${'a' * 64}"}'),
        throwsA(isA<RpcWebSocketProtocolException>()),
      );
      expect(
        () => limitedCodec.encode(RpcWebSocketCancelFrame('é' * 32)),
        throwsA(isA<RpcWebSocketProtocolException>()),
      );
    });

    test('When a protocol exception is printed then it includes its type', () {
      const error = RpcWebSocketProtocolException('bad frame');

      expect(error.toString(), 'RpcWebSocketProtocolException: bad frame');
    });
  });
}

import 'dart:convert';

import 'package:dart_orpc_client/dart_orpc_client.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('HttpRpcTransport', () {
    test('returns the data field from a successful RPC response', () async {
      final transport = HttpRpcTransport(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.toString(), 'http://localhost:3000/rpc');
          expect(jsonDecode(request.body), {
            'method': 'user.getById',
            'input': {'id': '1'},
          });

          return http.Response(
            jsonEncode({
              'data': {'id': '1', 'name': 'Ada Lovelace'},
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      final response = await transport.send(
        const RpcRequest(method: 'user.getById', input: {'id': '1'}),
      );

      expect(response, {'id': '1', 'name': 'Ada Lovelace'});
    });

    test('throws RpcException for an RPC error response', () async {
      final transport = HttpRpcTransport(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'NOT_FOUND',
                'message': 'User "404" was not found.',
              },
            }),
            404,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        () => transport.send(
          const RpcRequest(method: 'user.getById', input: {'id': '404'}),
        ),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.notFound)
              .having(
                (error) => error.message,
                'message',
                'User "404" was not found.',
              ),
        ),
      );
    });

    test('throws RpcClientException for malformed envelopes', () async {
      final transport = HttpRpcTransport(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'unexpected': true}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        () => transport.send(const RpcRequest(method: 'user.getById')),
        throwsA(
          isA<RpcClientException>().having(
            (error) => error.message,
            'message',
            'RPC response from http://localhost:3000/rpc must contain a "data" field.',
          ),
        ),
      );
    });
  });

  group('RpcCaller', () {
    test('decodes typed responses', () async {
      final caller = RpcCaller(
        _FakeTransport({'id': '1', 'name': 'Ada Lovelace'}),
      );

      final user = await caller.call<Map<String, Object?>>(
        method: 'user.getById',
        input: {'id': '1'},
        decode: (json) => expectJsonObject(json, context: 'typed response'),
      );

      expect(user['name'], 'Ada Lovelace');
    });

    test('wraps decode failures as RpcClientException', () async {
      final caller = RpcCaller(_FakeTransport({'id': '1'}));

      await expectLater(
        () => caller.call<String>(
          method: 'user.getById',
          decode: (json) => throw StateError('bad decode'),
        ),
        throwsA(
          isA<RpcClientException>().having(
            (error) => error.message,
            'message',
            contains('Failed to decode RPC response for "user.getById"'),
          ),
        ),
      );
    });
  });
}

final class _FakeTransport implements RpcTransport {
  const _FakeTransport(this.response);

  final Object? response;

  @override
  Future<Object?> send(RpcRequest request) async => response;
}

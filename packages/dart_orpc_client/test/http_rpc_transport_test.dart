import 'dart:convert';

import 'package:dart_orpc_client/dart_orpc_client.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'utils/http_rpc_test_utils.dart';

void main() {
  group('Given an HttpRpcTransport', () {
    test(
      'When an RPC response succeeds then it returns the data field',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: rpcTestBaseUrl,
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.toString(), rpcTestEndpoint);
            expect(jsonDecode(request.body), {
              'method': 'user.getById',
              'input': {'id': '1'},
            });

            return rpcDataResponse({'id': '1', 'name': 'Ada Lovelace'});
          }),
        );

        final response = await transport.send(
          const RpcRequest(method: 'user.getById', input: {'id': '1'}),
        );

        expect(response, {'id': '1', 'name': 'Ada Lovelace'});
      },
    );

    test('When an RPC error is returned then it throws RpcException', () async {
      final transport = HttpRpcTransport(
        baseUrl: rpcTestBaseUrl,
        client: MockClient((request) async {
          return rpcJsonResponse({
            'error': {
              'code': 'NOT_FOUND',
              'message': 'User "404" was not found.',
            },
          }, statusCode: 404);
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

    test(
      'When an envelope is malformed then it throws RpcClientException',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: rpcTestBaseUrl,
          client: MockClient((request) async {
            return rpcJsonResponse({'unexpected': true});
          }),
        );

        await expectLater(
          () => transport.send(const RpcRequest(method: 'user.getById')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              'RPC response from $rpcTestEndpoint must contain a "data" field.',
            ),
          ),
        );
      },
    );
  });

  group('Given an RpcCaller', () {
    test(
      'When a response is received then it decodes the typed result',
      () async {
        final caller = RpcCaller(
          _FakeTransport({'id': '1', 'name': 'Ada Lovelace'}),
        );

        final user = await caller.call<Map<String, Object?>>(
          method: 'user.getById',
          input: {'id': '1'},
          decode: (json) => expectJsonObject(json, context: 'typed response'),
        );

        expect(user['name'], 'Ada Lovelace');
      },
    );

    test(
      'When result decoding fails then it throws RpcClientException',
      () async {
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
      },
    );
  });

  group('Given an RpcClientException', () {
    test('When converted to text then it includes its type and message', () {
      const error = RpcClientException('network failed');

      expect(error.toString(), 'RpcClientException: network failed');
    });
  });
}

final class _FakeTransport implements RpcTransport {
  const _FakeTransport(this.response);

  final Object? response;

  @override
  Future<Object?> send(RpcRequest request) async => response;
}

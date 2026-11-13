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

    test(
      'When global and per-call auth options are configured then per-call values win',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: rpcTestBaseUrl,
          headers: const {'x-api-key': 'global-key'},
          bearerTokenProvider: () async => 'global-token',
          client: MockClient((request) async {
            expect(request.headers['x-api-key'], 'call-key');
            expect(request.headers['authorization'], 'Bearer call-token');
            return rpcDataResponse(true);
          }),
        );

        final response = await transport.sendWithOptions(
          const RpcRequest(method: 'secure.check'),
          options: const RpcCallOptions(
            headers: {'X-API-KEY': 'call-key'},
            bearerToken: 'call-token',
          ),
        );

        expect(response, isTrue);
      },
    );

    test(
      'When a token provider returns null then transport omits authorization',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: rpcTestBaseUrl,
          bearerTokenProvider: () => null,
          client: MockClient((request) async {
            expect(request.headers.containsKey('authorization'), isFalse);
            return rpcDataResponse(true);
          }),
        );

        await transport.send(const RpcRequest(method: 'public.check'));
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

  group('Given an HTTP error envelope with details', () {
    Future<RpcException> errorFrom(
      Object? details, {
      bool include = true,
    }) async {
      final transport = HttpRpcTransport(
        baseUrl: rpcTestBaseUrl,
        client: MockClient((request) async {
          return rpcJsonResponse({
            'error': {
              'code': 'CONFLICT',
              'message': 'Version conflict.',
              if (include) 'details': details,
            },
          }, statusCode: 409);
        }),
      );
      try {
        await transport.send(const RpcRequest(method: 'item.update'));
      } on RpcException catch (error) {
        return error;
      }
      fail('Expected an RpcException.');
    }

    test('When the details are an object then they are exposed', () async {
      final error = await errorFrom({
        'currentVersion': 3,
        'fields': ['name'],
      });

      expect(error.details, {
        'currentVersion': 3,
        'fields': ['name'],
      });
    });

    test(
      'When the details are an object then code and message are kept',
      () async {
        final error = await errorFrom({'currentVersion': 3});

        expect(error.code, RpcErrorCode.conflict);
        expect(error.message, 'Version conflict.');
      },
    );

    test('When the details are missing then they are null', () async {
      final error = await errorFrom(null, include: false);

      expect(error.details, isNull);
      expect(error.code, RpcErrorCode.conflict);
    });

    test('When the details are not an object then they are null', () async {
      for (final details in <Object?>[
        null,
        'text',
        3,
        true,
        ['a'],
      ]) {
        final error = await errorFrom(details);

        expect(error.details, isNull, reason: 'details: $details');
        expect(error.code, RpcErrorCode.conflict);
        expect(error.message, 'Version conflict.');
      }
    });
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

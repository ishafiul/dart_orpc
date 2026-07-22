import 'package:dart_orpc_client/dart_orpc_client.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'utils/http_rpc_test_utils.dart';

void main() {
  group('Given an HttpRpcTransport with interceptors', () {
    test(
      'When a request succeeds then separate request and response hooks run',
      () async {
        final events = <String>[];
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            expect(request.headers['x-request-hook'], 'true');
            events.add('http');
            return rpcDataResponse('before');
          }),
          interceptors: [_SimpleHooksInterceptor(events)],
        );

        final result = await transport.send(
          const RpcRequest(method: 'test.simple-hooks'),
        );

        expect(result, 'after');
        expect(events, ['request', 'http', 'response']);
      },
    );

    test('When a request fails then the error hook can recover', () async {
      final events = <String>[];
      final transport = HttpRpcTransport(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async => throw Exception('offline')),
        interceptors: [_SimpleHooksInterceptor(events)],
      );

      final result = await transport.send(
        const RpcRequest(method: 'test.simple-error'),
      );

      expect(result, 'recovered');
      expect(events, ['request', 'error']);
    });

    test(
      'When multiple interceptors run then requests and responses use middleware order',
      () async {
        final events = <String>[];
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            events.add('http');
            return rpcDataResponse('network');
          }),
          interceptors: [
            _RecordingInterceptor('first', events),
            _RecordingInterceptor('second', events),
          ],
        );

        await transport.send(const RpcRequest(method: 'test.order'));

        expect(events, [
          'first:request',
          'second:request',
          'http',
          'second:response',
          'first:response',
        ]);
      },
    );

    test(
      'When a request hook replaces HTTP data then the client receives it',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            expect(request.url.toString(), 'http://localhost:3000/custom-rpc');
            expect(request.headers['authorization'], 'Bearer token');
            expect(request.headers['accept'], 'application/json');
            return rpcDataResponse('authorized');
          }),
          interceptors: const [_AuthAndRouteInterceptor()],
        );

        final result = await transport.send(
          const RpcRequest(method: 'test.auth'),
        );

        expect(result, 'authorized');
      },
    );

    test(
      'When a response is transformed then RPC decoding uses the replacement',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async => rpcDataResponse('before')),
          interceptors: const [_ResponseInterceptor('after')],
        );

        final result = await transport.send(
          const RpcRequest(method: 'test.transform'),
        );

        expect(result, 'after');
      },
    );

    test(
      'When an interceptor short-circuits then the HTTP client is not invoked',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            fail('The HTTP client should not be invoked.');
          }),
          interceptors: const [_ShortCircuitInterceptor('cached')],
        );

        final result = await transport.send(
          const RpcRequest(method: 'test.cached'),
        );

        expect(result, 'cached');
      },
    );

    test(
      'When the HTTP client fails then a core interceptor can recover',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async => throw Exception('offline')),
          interceptors: const [_RecoveryInterceptor('fallback')],
        );

        final result = await transport.send(
          const RpcRequest(method: 'test.recovery'),
        );

        expect(result, 'fallback');
      },
    );

    test(
      'When retrying then only downstream interceptors are re-executed',
      () async {
        var attempts = 0;
        final events = <String>[];
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            attempts++;
            if (attempts < 3) throw Exception('temporary');
            return rpcDataResponse('retried');
          }),
          interceptors: [
            _RecordingInterceptor('outer', events),
            const _RetryInterceptor(maxAttempts: 3),
            _RecordingInterceptor('inner', events),
          ],
        );

        final result = await transport.send(
          const RpcRequest(method: 'test.retry'),
        );

        expect(result, 'retried');
        expect(attempts, 3);
        expect(events.where((event) => event == 'outer:request'), hasLength(1));
        expect(events.where((event) => event == 'inner:request'), hasLength(3));
      },
    );

    test(
      'When an interceptor fails then RpcClientException is thrown',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async => rpcDataResponse('unused')),
          interceptors: const [_ThrowingInterceptor()],
        );

        await expectLater(
          () => transport.send(const RpcRequest(method: 'test.failure')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains('interceptor failed'),
            ),
          ),
        );
      },
    );

    test(
      'When calls run concurrently then request state remains isolated',
      () async {
        final observedMethods = <String>[];
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            observedMethods.add(request.headers['x-rpc-method']!);
            return rpcDataResponse(request.headers['x-rpc-method']);
          }),
          interceptors: const [_MethodHeaderInterceptor()],
        );

        final results = await Future.wait([
          transport.send(const RpcRequest(method: 'first')),
          transport.send(const RpcRequest(method: 'second')),
        ]);

        expect(results, containsAll(['first', 'second']));
        expect(observedMethods, containsAll(['first', 'second']));
      },
    );

    test(
      'When headers are mutated then request and response maps reject changes',
      () {
        final rpcRequest = const RpcRequest(method: 'test.immutable');
        final request = HttpRpcRequest(
          method: 'POST',
          uri: Uri.parse('http://localhost/rpc'),
          headers: const {'accept': 'application/json'},
          body: '{}',
          rpcRequest: rpcRequest,
        );
        final response = HttpRpcResponse(
          statusCode: 200,
          headers: const {'content-type': 'application/json'},
          body: '{}',
          request: request,
        );

        expect(
          () => request.headers['authorization'] = 'token',
          throwsA(anything),
        );
        expect(() => response.headers['x-test'] = 'value', throwsA(anything));
      },
    );
  });

  group('Given immutable HTTP RPC values', () {
    test('When copyWith has no overrides then every value is preserved', () {
      final rpcRequest = const RpcRequest(method: 'test.copy');
      final request = HttpRpcRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/rpc'),
        headers: const {'accept': 'application/json'},
        body: '{}',
        rpcRequest: rpcRequest,
      );
      final response = HttpRpcResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: '{"data":null}',
        request: request,
      );

      final copiedRequest = request.copyWith();
      final copiedResponse = response.copyWith();

      expect(copiedRequest.method, request.method);
      expect(copiedRequest.uri, request.uri);
      expect(copiedRequest.headers, request.headers);
      expect(copiedRequest.body, request.body);
      expect(copiedRequest.rpcRequest, same(rpcRequest));
      expect(copiedResponse.statusCode, response.statusCode);
      expect(copiedResponse.headers, response.headers);
      expect(copiedResponse.body, response.body);
      expect(copiedResponse.request, same(request));
    });
  });

  group('Given an RpcInterceptor with default hooks', () {
    test('When a request succeeds then it passes through unchanged', () async {
      final transport = HttpRpcTransport(
        baseUrl: 'http://localhost:3000',
        client: MockClient((request) async => rpcDataResponse('unchanged')),
        interceptors: const [_DefaultRpcInterceptor()],
      );

      final result = await transport.send(
        const RpcRequest(method: 'test.default-success'),
      );

      expect(result, 'unchanged');
    });

    test(
      'When a request fails then the original failure is rethrown',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async => throw Exception('offline')),
          interceptors: const [_DefaultRpcInterceptor()],
        );

        await expectLater(
          () =>
              transport.send(const RpcRequest(method: 'test.default-failure')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains('offline'),
            ),
          ),
        );
      },
    );
  });
}

final class _DefaultRpcInterceptor extends RpcInterceptor {
  const _DefaultRpcInterceptor();
}

final class _SimpleHooksInterceptor extends RpcInterceptor {
  const _SimpleHooksInterceptor(this.events);

  final List<String> events;

  @override
  Future<HttpRpcRequest> onRequest(HttpRpcRequest request) async {
    events.add('request');
    return request.copyWith(
      headers: {...request.headers, 'x-request-hook': 'true'},
    );
  }

  @override
  Future<HttpRpcResponse> onResponse(HttpRpcResponse response) async {
    events.add('response');
    return response.copyWith(body: rpcDataBody('after'));
  }

  @override
  Future<HttpRpcResponse> onError(
    Object error,
    StackTrace stackTrace,
    HttpRpcRequest request,
  ) async {
    events.add('error');
    return HttpRpcResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: rpcDataBody('recovered'),
      request: request,
    );
  }
}

final class _RecordingInterceptor implements RpcInterceptorCore {
  const _RecordingInterceptor(this.name, this.events);

  final String name;
  final List<String> events;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) async {
    events.add('$name:request');
    try {
      return await next.next(request);
    } finally {
      events.add('$name:response');
    }
  }
}

final class _AuthAndRouteInterceptor implements RpcInterceptorCore {
  const _AuthAndRouteInterceptor();

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) {
    return next.next(
      request.copyWith(
        uri: request.uri.resolve('/custom-rpc'),
        headers: {...request.headers, 'authorization': 'Bearer token'},
      ),
    );
  }
}

final class _ResponseInterceptor implements RpcInterceptorCore {
  const _ResponseInterceptor(this.value);

  final Object? value;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) async {
    final response = await next.next(request);
    return response.copyWith(body: rpcDataBody(value));
  }
}

final class _ShortCircuitInterceptor implements RpcInterceptorCore {
  const _ShortCircuitInterceptor(this.value);

  final Object? value;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) async {
    return HttpRpcResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: rpcDataBody(value),
      request: request,
    );
  }
}

final class _RecoveryInterceptor implements RpcInterceptorCore {
  const _RecoveryInterceptor(this.value);

  final Object? value;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) async {
    try {
      return await next.next(request);
    } on Object {
      return HttpRpcResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: rpcDataBody(value),
        request: request,
      );
    }
  }
}

final class _RetryInterceptor implements RpcInterceptorCore {
  const _RetryInterceptor({required this.maxAttempts});

  final int maxAttempts;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await next.next(request);
      } on Object {
        if (attempt == maxAttempts) rethrow;
      }
    }
    throw StateError('Retry loop completed without a response.');
  }
}

final class _ThrowingInterceptor implements RpcInterceptorCore {
  const _ThrowingInterceptor();

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) {
    throw StateError('interceptor failed');
  }
}

final class _MethodHeaderInterceptor implements RpcInterceptorCore {
  const _MethodHeaderInterceptor();

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) {
    return next.next(
      request.copyWith(
        headers: {
          ...request.headers,
          'x-rpc-method': request.rpcRequest.method,
        },
      ),
    );
  }
}

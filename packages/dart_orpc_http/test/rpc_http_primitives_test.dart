import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('Given HTTP response bodies', () {
    test(
      'When copyWith replaces content then buffered and streaming kinds remain explicit',
      () async {
        const original = RpcHttpResponse(
          statusCode: HttpStatus.ok,
          body: 'one',
        );
        final stream = Stream<List<int>>.value(const [1, 2, 3]);

        final streaming = original.copyWith(
          statusCode: HttpStatus.accepted,
          content: RpcStreamingHttpBody(stream),
        );
        final buffered = streaming.copyWith(
          content: const RpcBufferedHttpBody('two'),
        );

        expect(streaming.statusCode, HttpStatus.accepted);
        expect(streaming.isStreaming, isTrue);
        expect(await (streaming.body! as Stream<List<int>>).single, [1, 2, 3]);
        expect(buffered.isStreaming, isFalse);
        expect(buffered.body, 'two');
      },
    );

    test(
      'When a REST procedure returns void then the response is 204 without a body',
      () async {
        const metadata = ProcedureMetadata(
          rpcMethod: 'status.clear',
          controllerNamespace: 'status',
          methodName: 'clear',
          outputTypeCode: 'void',
        );
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: RestRouteRegistry([
            RestUnaryRoute(
              method: 'DELETE',
              path: '/status',
              metadata: metadata,
              handler: (_, _, _) => null,
            ),
          ]),
        );

        final response = await handler(
          const RpcHttpRequest(method: 'DELETE', path: '/status'),
        );

        expect(response.statusCode, HttpStatus.noContent);
        expect(response.body, isNull);
        expect(response.headers, isEmpty);
      },
    );
  });

  group('Given a handler context factory', () {
    test(
      'When default bindings are configured then framework context fields and values are available',
      () async {
        const envKey = RpcContextKey<String>('app.env');
        final routes = RestRouteRegistry([
          RestUnaryRoute(
            method: 'GET',
            path: '/context',
            handler: (context, _, _) => {
              'method': context.httpMethod,
              'path': context.path,
              'env': context.requireBinding(envKey),
            },
          ),
        ]);
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: routes,
          bindings: const RpcContextBindings.empty().withValue(
            envKey,
            'production',
          ),
        );

        final response = await handler(
          const RpcHttpRequest(method: 'GET', path: '/context'),
        );

        expect(jsonDecode(response.body! as String), {
          'method': 'GET',
          'path': '/context',
          'env': 'production',
        });
      },
    );

    test(
      'When a REST route runs then custom context overrides bindings and preserves cancellation',
      () async {
        const tenantKey = RpcContextKey<String>('tenant');
        const envKey = RpcContextKey<String>('env');
        final cancellation = RpcCancellationSource();
        final routes = RestRouteRegistry([
          RestUnaryRoute(
            method: 'GET',
            path: '/context',
            handler: (context, _, _) => {
              'tenant': context.attributes['tenant'],
              'tenantBinding': context.requireBinding(tenantKey),
              'envBinding': context.requireBinding(envKey),
              'sameCancellation': identical(
                context.cancellation,
                cancellation.signal,
              ),
            },
          ),
        ]);
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: routes,
          bindings: const RpcContextBindings.empty()
              .withValue(tenantKey, 'default')
              .withValue(envKey, 'production'),
          contextFactory: (_) => RpcContext(
            headers: const {},
            attributes: const {'tenant': 'acme'},
            bindings: const RpcContextBindings.empty().withValue(
              tenantKey,
              'request',
            ),
          ),
        );

        final response = await handler(
          RpcHttpRequest(
            method: 'GET',
            path: '/context',
            cancellation: cancellation.signal,
          ),
        );

        expect(routes.routes, hasLength(1));
        expect(jsonDecode(response.body! as String), {
          'tenant': 'acme',
          'tenantBinding': 'request',
          'envBinding': 'production',
          'sameCancellation': true,
        });
      },
    );

    test(
      'When context construction fails unexpectedly then RPC returns the standard internal error',
      () async {
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry([
            RpcUnaryProcedure<Null, String>(
              method: 'test.value',
              metadata: const ProcedureMetadata(
                rpcMethod: 'test.value',
                controllerNamespace: 'test',
                methodName: 'value',
                outputTypeCode: 'String',
              ),
              decodeInput: (_) => null,
              encodeOutput: (output) => output,
              handler: (_, _) => 'value',
            ),
          ]),
          contextFactory: (_) => throw StateError('context failed'),
        );

        final response = await handler(
          const RpcHttpRequest(
            method: 'POST',
            path: '/rpc',
            body: '{"method":"test.value"}',
          ),
        );

        expect(response.statusCode, HttpStatus.internalServerError);
        expect(jsonDecode(response.body! as String), {
          'error': {
            'code': 'INTERNAL_ERROR',
            'message': 'Internal server error.',
          },
        });
      },
    );
  });
}

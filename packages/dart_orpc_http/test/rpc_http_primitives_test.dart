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
  });

  group('Given a handler context factory', () {
    test(
      'When a REST route runs then custom attributes and call cancellation are preserved',
      () async {
        final cancellation = RpcCancellationSource();
        final routes = RestRouteRegistry([
          RestUnaryRoute(
            method: 'GET',
            path: '/context',
            handler: (context, _, _) => {
              'tenant': context.attributes['tenant'],
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
          contextFactory: (_) => RpcContext(
            headers: const {},
            attributes: const {'tenant': 'acme'},
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

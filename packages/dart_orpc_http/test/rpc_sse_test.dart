import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('Given a generated SSE REST route', () {
    late RpcHttpHandler handler;

    setUp(() {
      handler = createRpcHttpHandler(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: RestRouteRegistry([
          RestStreamRoute(
            path: '/events',
            handler: (_, _, _) => Stream<Object?>.fromIterable([
              {'id': 1},
              {'id': 2},
            ]),
          ),
        ]),
        sseHeartbeatInterval: Duration.zero,
      );
    });

    group('When the route is requested', () {
      late RpcHttpResponse response;
      late String body;

      setUp(() async {
        response = await handler(
          const RpcHttpRequest(method: 'GET', path: '/events'),
        );
        body = await _readBody(response);
      });

      test('Then it returns event-stream headers', () {
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers['content-type'], contains('text/event-stream'));
        expect(response.headers['cache-control'], 'no-cache');
        expect(response.headers['x-accel-buffering'], 'no');
      });

      test('Then it emits ordered data and one completion event', () {
        expect(
          body,
          'data: {"id":1}\n\n'
          'data: {"id":2}\n\n'
          'event: dart-orpc-complete\n'
          'data: {}\n\n',
        );
      });
    });

    test(
      'When middleware copies the response then streaming is preserved',
      () async {
        final middlewareHandler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: RestRouteRegistry([
            RestStreamRoute(
              path: '/events',
              handler: (_, _, _) => Stream<Object?>.value({'id': 1}),
            ),
          ]),
          sseHeartbeatInterval: Duration.zero,
          middleware: [
            (next) => (request) async {
              final response = await next(request);
              return response.copyWith(
                headers: {...response.headers, 'x-wrapped': 'true'},
              );
            },
          ],
        );

        final response = await middlewareHandler(
          const RpcHttpRequest(method: 'GET', path: '/events'),
        );

        expect(response.isStreaming, isTrue);
        expect(response.headers['x-wrapped'], 'true');
        expect(await _readBody(response), contains('data: {"id":1}'));
      },
    );

    test(
      'When an empty stream completes then it emits only one completion event',
      () async {
        final emptyHandler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: RestRouteRegistry([
            RestStreamRoute(
              path: '/empty',
              handler: (_, _, _) => const Stream.empty(),
            ),
          ]),
          sseHeartbeatInterval: Duration.zero,
        );

        final response = await emptyHandler(
          const RpcHttpRequest(method: 'GET', path: '/empty'),
        );

        expect(
          await _readBody(response),
          'event: dart-orpc-complete\n'
          'data: {}\n\n',
        );
      },
    );

    test(
      'When a guard rejects before streaming starts then it returns the normal JSON RPC error',
      () async {
        final guardedHandler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: RestRouteRegistry([
            RestStreamRoute(
              path: '/guarded',
              handler: (_, _, _) => const Stream.empty(),
              metadata: const ProcedureMetadata(
                rpcMethod: 'events.guarded',
                controllerNamespace: 'events',
                methodName: 'guarded',
                outputTypeCode: 'JsonObject',
                kind: RpcProcedureKind.serverStream,
              ),
              guards: const [_RejectingGuard()],
            ),
          ]),
        );

        final response = await guardedHandler(
          const RpcHttpRequest(method: 'GET', path: '/guarded'),
        );

        expect(response.statusCode, HttpStatus.forbidden);
        expect(response.isStreaming, isFalse);
        expect(jsonDecode(response.body! as String), {
          'error': {'code': 'FORBIDDEN', 'message': 'denied'},
        });
      },
    );

    test(
      'When input decoding fails before returning a stream then it returns a JSON error',
      () async {
        final invalidInputHandler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: RestRouteRegistry([
            RestStreamRoute(
              path: '/invalid',
              handler: (_, _, _) {
                throw RpcException.badRequest('invalid stream input');
              },
            ),
          ]),
        );

        final response = await invalidInputHandler(
          const RpcHttpRequest(method: 'GET', path: '/invalid'),
        );

        expect(response.statusCode, HttpStatus.badRequest);
        expect(response.isStreaming, isFalse);
        expect(jsonDecode(response.body! as String), {
          'error': {'code': 'BAD_REQUEST', 'message': 'invalid stream input'},
        });
      },
    );
  });

  group('Given an SSE stream that fails after starting', () {
    test('When it fails then it emits one RPC error terminal event', () async {
      final controller = StreamController<Object?>();
      final body = encodeSseResponseBody(
        controller.stream,
        heartbeatInterval: Duration.zero,
      );
      final bodyFuture = utf8.decodeStream(body);

      controller
        ..add({'id': 1})
        ..addError(RpcException.forbidden('denied'));
      await controller.close();

      expect(
        await bodyFuture,
        'data: {"id":1}\n\n'
        'event: dart-orpc-error\n'
        'data: {"error":{"code":"FORBIDDEN","message":"denied"}}\n\n',
      );
    });
  });

  group('Given a listening SSE consumer', () {
    test('When it cancels then the procedure source is cancelled', () async {
      var sourceCancelled = false;
      late StreamController<Object?> source;
      source = StreamController<Object?>(
        onListen: () => source.add({'id': 1}),
        onCancel: () => sourceCancelled = true,
      );
      final subscription = encodeSseResponseBody(
        source.stream,
        heartbeatInterval: Duration.zero,
      ).listen((_) {});

      await subscription.cancel();

      expect(sourceCancelled, isTrue);
      await source.close();
    });

    test(
      'When no application events arrive then heartbeat comments are emitted',
      () async {
        final source = StreamController<Object?>();
        final firstChunk = await encodeSseResponseBody(
          source.stream,
          heartbeatInterval: const Duration(milliseconds: 1),
        ).first.timeout(const Duration(seconds: 2));

        expect(utf8.decode(firstChunk), ': dart-orpc-ping\n\n');
        await source.close();
      },
    );

    test(
      'When the HTTP consumer pauses then source production is backpressured',
      () async {
        final paused = Completer<void>();
        final resumed = Completer<void>();
        final source = StreamController<Object?>(
          onPause: paused.complete,
          onResume: resumed.complete,
        );
        final subscription = encodeSseResponseBody(
          source.stream,
          heartbeatInterval: Duration.zero,
        ).listen((_) {});

        subscription.pause();
        await paused.future.timeout(const Duration(seconds: 2));
        subscription.resume();
        await resumed.future.timeout(const Duration(seconds: 2));
        await subscription.cancel();
        await source.close();

        expect(source.hasListener, isFalse);
      },
    );
  });

  group('Given an SSE route on a real loopback server', () {
    test(
      'When the first event is produced then it is flushed before the source completes',
      () async {
        final source = StreamController<Object?>();
        final app = RpcHttpApp(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: RestRouteRegistry([
            RestStreamRoute(
              path: '/events',
              handler: (_, _, _) => source.stream,
            ),
          ]),
          sseHeartbeatInterval: Duration.zero,
        );
        final server = await app.listen(
          0,
          hostname: InternetAddress.loopbackIPv4.address,
        );
        addTearDown(() => server.close(force: true));
        addTearDown(source.close);
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final request = await client.getUrl(
          Uri.parse('http://${server.address.address}:${server.port}/events'),
        );
        final responseFuture = request.close();
        source.add(const {'text': 'ready'});
        final response = await responseFuture;
        final firstEvent = Completer<String>();
        final completedBody = Completer<String>();
        final buffer = StringBuffer();
        final subscription = response
            .transform(utf8.decoder)
            .listen(
              (chunk) {
                buffer.write(chunk);
                final body = buffer.toString();
                if (!firstEvent.isCompleted && body.contains('héllo\\nworld')) {
                  firstEvent.complete(body);
                }
              },
              onError: completedBody.completeError,
              onDone: () => completedBody.complete(buffer.toString()),
            );
        addTearDown(subscription.cancel);
        source.add({'text': 'héllo\nworld'});

        final partial = await firstEvent.future.timeout(
          const Duration(seconds: 2),
        );

        expect(partial, contains('data: {"text":"héllo\\nworld"}\n\n'));
        expect(source.isClosed, isFalse);

        source.add(const {'text': 'second'});
        await source.close();
        final fullBody = await completedBody.future.timeout(
          const Duration(seconds: 2),
        );
        expect(fullBody, endsWith('event: dart-orpc-complete\ndata: {}\n\n'));
      },
    );

    test(
      'When graceful shutdown reaches its deadline then the source is cancelled',
      () async {
        final cancelled = Completer<void>();
        late StreamController<Object?> source;
        source = StreamController<Object?>(onCancel: cancelled.complete);
        final app = RpcHttpApp(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: RestRouteRegistry([
            RestStreamRoute(
              path: '/events',
              handler: (_, _, _) => source.stream,
            ),
          ]),
          sseHeartbeatInterval: Duration.zero,
        );
        final server = await app.listen(
          0,
          hostname: InternetAddress.loopbackIPv4.address,
        );
        addTearDown(() => server.close(force: true));
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final request = await client.getUrl(
          Uri.parse('http://${server.address.address}:${server.port}/events'),
        );
        final responseFuture = request.close();
        source.add(const {'value': 0});
        final response = await responseFuture;
        final firstChunk = Completer<void>();
        final subscription = response.listen((_) {
          if (!firstChunk.isCompleted) {
            firstChunk.complete();
          }
        });
        addTearDown(subscription.cancel);
        source.add(const {'value': 1});
        await firstChunk.future.timeout(const Duration(seconds: 2));

        await server.close(gracePeriod: Duration.zero);

        await cancelled.future.timeout(const Duration(seconds: 2));
        expect(source.hasListener, isFalse);
      },
    );
  });
}

final class _RejectingGuard implements RpcGuard {
  const _RejectingGuard();

  @override
  void canActivate(RpcGuardContext context) {
    throw RpcException.forbidden('denied');
  }
}

Future<String> _readBody(RpcHttpResponse response) {
  final content = response.content;
  if (content is! RpcStreamingHttpBody) {
    throw StateError('Expected a streaming response.');
  }
  return utf8.decodeStream(content.chunks);
}

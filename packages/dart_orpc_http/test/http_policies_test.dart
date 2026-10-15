import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  Future<Uri> serve(RpcHttpApp app) async {
    final server = await app.listen(0, hostname: '127.0.0.1');
    addTearDown(() => server.close(force: true));
    return Uri.parse('http://127.0.0.1:${server.port}');
  }

  HttpClient client() {
    final result = HttpClient();
    addTearDown(() => result.close(force: true));
    return result;
  }

  RpcProcedureRegistry empty() => RpcProcedureRegistry(const []);

  test(
    'adapter errors have typed codes, final CORS headers, request IDs and completion events',
    () async {
      final errors = <RpcHttpErrorEvent>[];
      final completions = <RpcHttpCompletion>[];
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          maxRequestBodyBytes: 2,
          serverOptions: RpcHttpServerOptions(
            cors: const CorsOptions(),
            requestIdFactory: () => 'request-1',
            onError: errors.add,
            onComplete: completions.add,
          ),
        ),
      );
      final request = await client().postUrl(base.resolve('/rpc'));
      request.headers.contentType = ContentType.json;
      request.write('long body');
      final response = await request.close();
      expect(response.statusCode, 413);
      expect(response.headers.value('access-control-allow-origin'), '*');
      expect(response.headers.value('x-request-id'), 'request-1');
      expect(
        jsonDecode(await utf8.decodeStream(response)),
        containsPair('error', containsPair('code', 'PAYLOAD_TOO_LARGE')),
      );
      expect(errors, hasLength(1));
      expect(
        (errors.single.error as RpcException).code,
        RpcErrorCode.payloadTooLarge,
      );
      expect(completions, hasLength(1));
      expect(completions.single.statusCode, 413);
      expect(completions.single.failed, isTrue);
    },
  );

  test(
    'RPC hooks report original exception once and context contains correlation ID',
    () async {
      final errors = <RpcHttpErrorEvent>[];
      final failure = StateError('private details');
      final base = await serve(
        RpcHttpApp(
          procedures: RpcProcedureRegistry([
            RpcUnaryProcedure<Null, String>(
              method: 'test.fail',
              metadata: const ProcedureMetadata(
                rpcMethod: 'test.fail',
                controllerNamespace: 'test',
                methodName: 'fail',
                outputTypeCode: 'String',
              ),
              decodeInput: (_) => null,
              encodeOutput: (value) => value,
              handler: (context, _) {
                expect(context.requireBinding(rpcRequestIdKey), 'trace');
                throw failure;
              },
            ),
          ]),
          serverOptions: RpcHttpServerOptions(
            onError: errors.add,
            requestIdFactory: () => 'trace',
          ),
        ),
      );
      final request = await client().postUrl(base.resolve('/rpc'));
      request.write('{"method":"test.fail"}');
      final response = await request.close();
      expect(response.statusCode, 500);
      final body = await utf8.decodeStream(response);
      expect(body, isNot(contains('private details')));
      expect(errors.single.error, same(failure));
      expect(errors.single.stackTrace.toString(), isNotEmpty);
    },
  );

  test('hook failures cannot break responses and are counted', () async {
    final base = await serve(
      RpcHttpApp(
        procedures: empty(),
        metrics: const RpcHttpMetricsOptions(),
        serverOptions: RpcHttpServerOptions(
          onError: (_) => throw StateError('observer'),
          onComplete: (_) => throw StateError('completion'),
        ),
        middleware: [
          (next) =>
              (request) => request.path == '/failure'
              ? Future.error(StateError('handler'))
              : next(request),
        ],
      ),
    );
    final http = client();
    final failed = await (await http.getUrl(base.resolve('/failure'))).close();
    expect(failed.statusCode, 500);
    await failed.drain<void>();
    final metrics = await (await http.getUrl(base.resolve('/metrics'))).close();
    final body = jsonDecode(await utf8.decodeStream(metrics)) as Map;
    expect(body['hook_errors'], 2);
    expect(
      (body['routes'] as Map)['GET /unmatched'],
      containsPair('errors', 1),
    );
  });

  test(
    'handler deadline signals cooperative cancellation and releases admission capacity',
    () async {
      final cancelled = Completer<void>();
      final completions = <RpcHttpCompletion>[];
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          maxConcurrentRequests: 1,
          serverOptions: RpcHttpServerOptions(
            handlerTimeout: const Duration(milliseconds: 50),
            onComplete: completions.add,
          ),
          restRoutes: RestRouteRegistry([
            RestUnaryRoute(
              method: 'GET',
              path: '/slow',
              handler: (context, _, _) async {
                await context.cancellation.cancelled;
                cancelled.complete();
                return 'late result';
              },
            ),
            RestUnaryRoute(
              method: 'GET',
              path: '/fast',
              handler: (_, _, _) => 'ok',
            ),
          ]),
        ),
      );
      final http = client();
      final response = await (await http.getUrl(base.resolve('/slow'))).close();
      expect(response.statusCode, 504);
      expect(await utf8.decodeStream(response), contains('DEADLINE_EXCEEDED'));
      await cancelled.future.timeout(const Duration(seconds: 2));
      final recovered = await (await http.getUrl(
        base.resolve('/fast'),
      )).close();
      expect(recovered.statusCode, 200);
      await recovered.drain<void>();
      expect(
        completions.where((value) => value.route == '/slow'),
        hasLength(1),
      );
    },
  );

  test('total upload deadline is distinct from body idle timeout', () async {
    final base = await serve(
      RpcHttpApp(
        procedures: empty(),
        requestBodyIdleTimeout: const Duration(seconds: 1),
        serverOptions: const RpcHttpServerOptions(
          bodyTimeout: Duration(milliseconds: 50),
          cors: CorsOptions(),
        ),
      ),
    );
    final socket = await Socket.connect(base.host, base.port);
    addTearDown(socket.destroy);
    final response = utf8.decodeStream(socket);
    socket.write(
      'POST /rpc HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n1\r\nx\r\n',
    );
    await socket.flush();
    final raw = await response.timeout(const Duration(seconds: 3));
    expect(raw, startsWith('HTTP/1.1 408'));
    expect(raw, contains('Request body deadline exceeded.'));
    expect(raw.toLowerCase(), contains('access-control-allow-origin: *'));
  });

  test('header limit rejects before controller with 431', () async {
    final base = await serve(
      RpcHttpApp(
        procedures: empty(),
        serverOptions: const RpcHttpServerOptions(
          maxHeaderBytes: 150,
          cors: CorsOptions(),
        ),
      ),
    );
    final request = await client().getUrl(base);
    request.headers.set('x-large', 'x' * 1000);
    final response = await request.close();
    expect(response.statusCode, 431);
    expect(await utf8.decodeStream(response), contains('HEADERS_TOO_LARGE'));
  });

  test(
    'raw bytes, repeated query values, original URI, cookies and peer address survive conversion',
    () async {
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          middleware: [
            (next) => (request) async {
              expect(request.bodyBytes, [0xff, 0x00, 0x01]);
              expect(request.queryParametersAll['tag'], ['a', 'b']);
              expect(request.uri?.query, 'tag=a&tag=b');
              expect(request.remoteAddress, '127.0.0.1');
              expect(request.cookies, {'session': 'one', 'preference': 'dark'});
              expect(
                () => request.queryParametersAll['tag']!.add('c'),
                throwsUnsupportedError,
              );
              return const RpcHttpResponse(
                statusCode: 200,
                body: 'binary accepted',
              );
            },
          ],
        ),
      );
      final request = await client().postUrl(
        base.resolve('/binary?tag=a&tag=b'),
      );
      request.headers.set('cookie', 'session=one; preference=dark');
      request.add([0xff, 0, 1]);
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(await utf8.decodeStream(response), 'binary accepted');
    },
  );

  test(
    'invalid UTF-8 and unsupported RPC content types are client errors',
    () async {
      final base = await serve(RpcHttpApp(procedures: empty()));
      final http = client();
      for (final (bytes, contentType, status) in [
        ([0xff], 'application/json', 400),
        ([123, 125], 'text/plain', 415),
      ]) {
        final request = await http.postUrl(base.resolve('/rpc'));
        request.headers.set('content-type', contentType);
        request.add(bytes);
        final response = await request.close();
        expect(response.statusCode, status);
        await response.drain<void>();
      }
    },
  );

  test(
    'metrics aggregate by route template and never retain arbitrary URL labels',
    () async {
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          metrics: const RpcHttpMetricsOptions(),
          restRoutes: RestRouteRegistry([
            RestUnaryRoute(
              method: 'GET',
              path: '/items/:id',
              handler: (_, _, path) => path,
            ),
          ]),
        ),
      );
      final http = client();
      for (final path in [
        '/items/one',
        '/items/two',
        '/unknown/one',
        '/unknown/two',
      ]) {
        await (await (await http.getUrl(
          base.resolve(path),
        )).close()).drain<void>();
      }
      final response = await (await http.getUrl(
        base.resolve('/metrics'),
      )).close();
      final stats = jsonDecode(await utf8.decodeStream(response)) as Map;
      final routes = stats['routes'] as Map;
      expect(
        routes.keys,
        unorderedEquals(['GET /items/:id', 'GET /unmatched']),
      );
      expect(routes['GET /items/:id']['requests'], 2);
      expect(routes['GET /unmatched']['errors'], 2);
      expect(routes['GET /items/:id']['duration_seconds_buckets']['+Inf'], 2);
      expect(stats['active_requests'], 1); // The metrics request itself.
      expect(stats['active_streams'], 0);
    },
  );

  test('rate limiter has deterministic windows and a hard identity bound', () {
    var now = DateTime.utc(2026);
    final limiter = RpcHttpRateLimiter(
      const RpcHttpRateLimitOptions(
        maxRequests: 2,
        maxKeys: 1,
        window: Duration(seconds: 10),
      ),
      clock: () => now,
    );
    const one = RpcHttpRequest(method: 'GET', path: '/', remoteAddress: 'one');
    const two = RpcHttpRequest(method: 'GET', path: '/', remoteAddress: 'two');
    expect(limiter.check(one), isNull);
    expect(limiter.check(one), isNull);
    expect(limiter.check(one), const Duration(seconds: 10));
    expect(limiter.check(two), isNotNull);
    now = now.add(const Duration(seconds: 10));
    expect(limiter.check(two), isNull);
  });

  test('rate limit returns 429 and Retry-After with CORS', () async {
    final base = await serve(
      RpcHttpApp(
        procedures: empty(),
        serverOptions: const RpcHttpServerOptions(
          cors: CorsOptions(),
          rateLimit: RpcHttpRateLimitOptions(maxRequests: 1),
        ),
      ),
    );
    final http = client();
    await (await (await http.getUrl(base)).close()).drain<void>();
    final response = await (await http.getUrl(base)).close();
    expect(response.statusCode, 429);
    expect(int.parse(response.headers.value('retry-after')!), greaterThan(0));
    expect(response.headers.value('access-control-allow-origin'), '*');
    expect(await utf8.decodeStream(response), contains('RESOURCE_EXHAUSTED'));
  });

  test(
    'readiness can fail or time out while liveness remains healthy',
    () async {
      final ready = Completer<bool>();
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          health: RpcHttpHealthOptions(
            livenessPath: '/live',
            readinessPath: '/ready',
            readinessCheck: () => ready.future,
            checkTimeout: const Duration(milliseconds: 30),
          ),
        ),
      );
      final http = client();
      final live = await (await http.getUrl(base.resolve('/live'))).close();
      expect(live.statusCode, 200);
      await live.drain<void>();
      final notReady = await (await http.getUrl(
        base.resolve('/ready'),
      )).close();
      expect(notReady.statusCode, 503);
      await notReady.drain<void>();
      ready.complete(true);
      final healthy = await (await http.getUrl(base.resolve('/ready'))).close();
      expect(healthy.statusCode, 200);
      await healthy.drain<void>();
    },
  );

  test(
    'compression negotiates gzip and HEAD does not send response body',
    () async {
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          serverOptions: const RpcHttpServerOptions(compress: true),
          restRoutes: RestRouteRegistry([
            RestUnaryRoute(
              method: 'GET',
              path: '/text',
              handler: (_, _, _) => 'hello ' * 3000,
            ),
          ]),
        ),
      );
      final http = client()..autoUncompress = false;
      final request = await http.getUrl(base.resolve('/text'));
      request.headers.set('accept-encoding', 'gzip');
      final response = await request.close();
      expect(response.headers.value('content-encoding'), 'gzip');
      final compressed = await response.expand((chunk) => chunk).toList();
      expect(jsonDecode(utf8.decode(gzip.decode(compressed))), 'hello ' * 3000);
      for (final (accept, encoded) in [
        ('gzip;q=0', false),
        ('gzip;q=0.5', true),
        ('*;q=1', true),
        ('gzip;q=0, *;q=1', false),
      ]) {
        final next = await http.getUrl(base.resolve('/text'));
        next.headers.set('accept-encoding', accept);
        final varied = await next.close();
        expect(
          varied.headers.value('content-encoding') == 'gzip',
          encoded,
          reason: accept,
        );
        expect(varied.headers.value('vary'), contains('Accept-Encoding'));
        await varied.drain<void>();
      }
      final head = await (await http.openUrl(
        'HEAD',
        base.resolve('/text'),
      )).close();
      expect(head.statusCode, 200);
      expect(await head.expand((chunk) => chunk).toList(), isEmpty);
    },
  );

  test(
    'disconnecting SSE consumer cancels upstream and completes lifecycle',
    () async {
      final sourceCancelled = Completer<void>();
      final finished = Completer<RpcHttpCompletion>();
      final source = StreamController<Object?>(
        onCancel: sourceCancelled.complete,
      );
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          sseHeartbeatInterval: const Duration(milliseconds: 20),
          serverOptions: RpcHttpServerOptions(onComplete: finished.complete),
          restRoutes: RestRouteRegistry([
            RestStreamRoute(
              path: '/events',
              handler: (_, _, _) => source.stream,
            ),
          ]),
        ),
      );
      final http = client();
      final responseFuture = (await http.getUrl(
        base.resolve('/events'),
      )).close();
      source.add({'first': true});
      final response = await responseFuture;
      final first = Completer<void>();
      final subscription = response.listen((_) {
        if (!first.isCompleted) first.complete();
      });
      addTearDown(subscription.cancel);
      await first.future.timeout(const Duration(seconds: 2));
      http.close(force: true);
      await sourceCancelled.future.timeout(const Duration(seconds: 2));
      final event = await finished.future.timeout(const Duration(seconds: 2));
      expect(event.disconnected, isTrue);
      await source.close();
    },
  );

  test(
    'request ID trust is opt-in and malformed IDs never enter response headers',
    () async {
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          serverOptions: RpcHttpServerOptions(
            trustRequestId: true,
            requestIdFactory: () => 'generated',
          ),
        ),
      );
      final http = client();
      for (final (incoming, expected) in [
        ('external-id', 'external-id'),
        ('not valid', 'generated'),
      ]) {
        final request = await http.getUrl(base);
        request.headers.set('x-request-id', incoming);
        final response = await request.close();
        expect(response.headers.value('x-request-id'), expected);
        await response.drain<void>();
      }
    },
  );

  test(
    'stream failures after first bytes are reported once without rewriting headers',
    () async {
      final errors = <RpcHttpErrorEvent>[];
      final completed = Completer<RpcHttpCompletion>();
      final source = StreamController<List<int>>();
      final base = await serve(
        RpcHttpApp(
          procedures: empty(),
          serverOptions: RpcHttpServerOptions(
            onError: errors.add,
            onComplete: completed.complete,
          ),
          middleware: [
            (next) =>
                (_) async => RpcHttpResponse.streaming(
                  statusCode: 200,
                  body: source.stream,
                ),
          ],
        ),
      );
      final responseFuture = (await client().getUrl(base)).close();
      source.add(utf8.encode('first'));
      final response = await responseFuture;
      final first = Completer<void>();
      final done = Completer<void>();
      final subscription = response.listen(
        (_) {
          if (!first.isCompleted) first.complete();
        },
        onError: (Object _) {
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      addTearDown(subscription.cancel);
      await first.future.timeout(const Duration(seconds: 2));
      source.addError(StateError('stream failure'));
      await done.future.timeout(const Duration(seconds: 2));
      final event = await completed.future.timeout(const Duration(seconds: 2));
      expect(errors, hasLength(1));
      expect(event.failed, isTrue);
      expect(event.streaming, isTrue);
      await source.close();
    },
  );
}

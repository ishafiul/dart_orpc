import 'dart:convert';
import 'dart:io';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  test(
    'request copies preserve transport metadata while replacing text or bytes',
    () {
      final source = RpcCancellationSource();
      final request = RpcHttpRequest(
        method: 'POST',
        path: '/old',
        bodyBytes: const [65],
        requestId: 'trace',
        uri: Uri.parse('/old?q=one&q=two'),
        remoteAddress: '127.0.0.1',
        cancellation: source.signal,
        queryParametersAll: const {
          'q': ['one', 'two'],
        },
        onError: (_, _) {},
      );
      final copy = request.copyWith(path: '/new', headers: {'x-added': 'yes'});
      expect(copy.body, 'A');
      expect(copy.requestId, 'trace');
      expect(copy.cancellation, same(source.signal));
      expect(copy.onError, same(request.onError));
      expect(copy.queryParametersAll, request.queryParametersAll);
      expect(copy.uri, request.uri);
      expect(copy.copyWith(body: 'text').bodyBytes, utf8.encode('text'));
      expect(copy.copyWith(bodyBytes: const [66]).body, 'B');
    },
  );

  test(
    'controller format exceptions remain internal errors after parsing succeeds',
    () async {
      final handler = createRpcHttpHandler(
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
            handler: (_, _) => throw const FormatException('private'),
          ),
        ]),
      );
      final response = await handler(
        const RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          body: '{"method":"test.fail"}',
        ),
      );
      expect(response.statusCode, 500);
      expect(response.body, isNot(contains('private')));
    },
  );

  test(
    'credentialed CORS requires explicit origins and validates preflight method and headers',
    () async {
      var calls = 0;
      final handler =
          createCorsMiddleware(
            const CorsOptions(
              allowCredentials: true,
              allowedOrigins: ['https://allowed.example'],
              allowMethods: ['GET'],
              allowHeaders: ['X-Token'],
            ),
          )((_) async {
            calls++;
            return const RpcHttpResponse(
              statusCode: 200,
              headers: {'Vary': 'Accept-Encoding'},
              body: 'ok',
            );
          });
      for (final (origin, method, headers, expected) in [
        ('https://allowed.example', 'GET', 'x-token', 204),
        ('https://evil.example', 'GET', 'x-token', 403),
        ('https://allowed.example', 'DELETE', 'x-token', 403),
        ('https://allowed.example', 'GET', 'x-unknown', 403),
      ]) {
        final response = await handler(
          RpcHttpRequest(
            method: 'OPTIONS',
            path: '/',
            headers: {
              'Origin': origin,
              'Access-Control-Request-Method': method,
              'Access-Control-Request-Headers': headers,
            },
          ),
        );
        expect(response.statusCode, expected);
        expect(response.headers['vary'], contains('Origin'));
        if (origin.contains('evil'))
          expect(response.headers['access-control-allow-origin'], isNull);
      }
      expect(calls, 0);
      final response = await handler(
        const RpcHttpRequest(
          method: 'GET',
          path: '/',
          headers: {'origin': 'https://allowed.example'},
        ),
      );
      expect(response.headers['vary'], 'Accept-Encoding, Origin');
      expect(response.headers['access-control-allow-credentials'], 'true');
      final unsafe =
          await createCorsMiddleware(const CorsOptions(allowCredentials: true))(
            (_) async => const RpcHttpResponse(statusCode: 200),
          )(
            const RpcHttpRequest(
              method: 'GET',
              path: '/',
              headers: {'origin': 'https://evil.example'},
            ),
          );
      expect(unsafe.headers['access-control-allow-origin'], isNull);
    },
  );

  test(
    'CORS predicates support dynamic origins without cache leakage',
    () async {
      final handler = createCorsMiddleware(
        CorsOptions(
          allowOriginPredicate: (origin) => origin == 'https://one.example',
        ),
      )((_) async => const RpcHttpResponse(statusCode: 200));
      for (final origin in ['https://one.example', 'https://two.example']) {
        final response = await handler(
          RpcHttpRequest(method: 'GET', path: '/', headers: {'origin': origin}),
        );
        expect(
          response.headers['access-control-allow-origin'],
          origin.contains('one') ? origin : isNull,
        );
      }
    },
  );

  test(
    'declared REST status and headers apply without changing payload',
    () async {
      final handler = createRpcHttpHandler(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: RestRouteRegistry([
          RestUnaryRoute(
            method: 'POST',
            path: '/items',
            metadata: const ProcedureMetadata(
              rpcMethod: 'items.create',
              controllerNamespace: 'items',
              methodName: 'create',
              outputTypeCode: 'JsonObject',
              path: RestProcedureMetadata(
                method: 'POST',
                path: '/items',
                statusCode: 201,
                headers: {'x-api-version': '1'},
              ),
            ),
            handler: (_, _, _) => {'id': 1},
          ),
        ]),
      );
      final response = await handler(
        const RpcHttpRequest(method: 'POST', path: '/items'),
      );
      expect(response.statusCode, 201);
      expect(response.headers['x-api-version'], '1');
      expect(jsonDecode(response.body! as String), {'id': 1});
    },
  );

  test(
    'HTTP response control preserves RPC envelopes while allowing REST metadata',
    () async {
      Map<String, Object?> procedure(RpcContext context) {
        final control = context.binding(rpcHttpResponseKey);
        control?.statusCode = 201;
        control?.headers['x-created'] = 'yes';
        control?.cookies.add(Cookie('session', 'new'));
        return {'id': 1};
      }

      final handler = createRpcHttpHandler(
        procedures: RpcProcedureRegistry([
          RpcUnaryProcedure<Null, Map<String, Object?>>(
            method: 'items.create',
            metadata: const ProcedureMetadata(
              rpcMethod: 'items.create',
              controllerNamespace: 'items',
              methodName: 'create',
              outputTypeCode: 'JsonObject',
            ),
            decodeInput: (_) => null,
            encodeOutput: (value) => value,
            handler: (context, _) => procedure(context),
          ),
        ]),
        restRoutes: RestRouteRegistry([
          RestUnaryRoute(
            method: 'POST',
            path: '/items',
            handler: (context, _, _) => procedure(context),
          ),
        ]),
      );
      final rpc = await handler(
        const RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          body: '{"method":"items.create"}',
        ),
      );
      final rest = await handler(
        const RpcHttpRequest(method: 'POST', path: '/items'),
      );
      expect(rpc.statusCode, 200);
      expect(jsonDecode(rpc.body! as String), {
        'data': {'id': 1},
      });
      expect(rest.statusCode, 201);
      expect(jsonDecode(rest.body! as String), {'id': 1});
      for (final response in [rpc, rest]) {
        expect(response.headers['x-created'], 'yes');
        expect(response.cookies.single.name, 'session');
      }
    },
  );

  test(
    'typed HTTP response supports redirects, cookies, repeated headers and downloads',
    () async {
      final directory = await Directory.systemTemp.createTemp('orpc-response');
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/report.txt',
      ).writeAsString('report');
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: RestRouteRegistry([
          RestUnaryRoute(
            method: 'GET',
            path: '/redirect',
            handler: (_, _, _) =>
                RpcHttpResponse.redirect(Uri.parse('/destination')),
          ),
          RestUnaryRoute(
            method: 'GET',
            path: '/cookies',
            handler: (_, _, _) => RpcHttpResponse(
              statusCode: 201,
              cookies: [
                Cookie('one', '1')..httpOnly = true,
                Cookie('two', '2'),
              ],
              headerValues: const {
                'x-many': ['one', 'two'],
              },
              body: 'created',
            ),
          ),
          RestUnaryRoute(
            method: 'GET',
            path: '/download',
            handler: (_, _, _) =>
                RpcHttpResponse.download(file, filename: 'report.txt'),
          ),
        ]),
        middleware: [createCorsMiddleware()],
      );
      final server = await app.listen(0, hostname: '127.0.0.1');
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final base = Uri.parse('http://127.0.0.1:${server.port}');
      final request = await client.getUrl(base.resolve('/redirect'));
      request.followRedirects = false;
      final redirected = await request.close();
      expect(redirected.statusCode, 302);
      expect(redirected.headers.value('location'), '/destination');
      await redirected.drain<void>();
      final cookies = await (await client.getUrl(
        base.resolve('/cookies'),
      )).close();
      expect(cookies.statusCode, 201);
      expect(cookies.cookies.map((cookie) => cookie.name), ['one', 'two']);
      expect(cookies.cookies.first.httpOnly, isTrue);
      expect(cookies.headers['x-many']!.join(','), contains('one'));
      await cookies.drain<void>();
      final download = await (await client.getUrl(
        base.resolve('/download'),
      )).close();
      expect(download.contentLength, 6);
      expect(
        download.headers.value('content-disposition'),
        'attachment; filename="report.txt"',
      );
      expect(await utf8.decodeStream(download), 'report');
      expect(
        () => RpcHttpResponse.download(file, filename: 'bad\r\nheader'),
        throwsArgumentError,
      );
    },
  );

  test(
    'static single byte ranges support bounded, suffix, open and unsatisfiable ranges',
    () async {
      final directory = await Directory.systemTemp.createTemp('orpc-range');
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/data.txt').writeAsString('0123456789');
      final handler = createRpcHttpHandler(
        procedures: RpcProcedureRegistry(const []),
        staticAssets: RpcHttpStaticOptions(directory: directory.path),
      );
      for (final (range, status, text, contentRange) in [
        ('bytes=2-5', 206, '2345', 'bytes 2-5/10'),
        ('bytes=-3', 206, '789', 'bytes 7-9/10'),
        ('bytes=8-', 206, '89', 'bytes 8-9/10'),
        ('bytes=8-100', 206, '89', 'bytes 8-9/10'),
        ('bytes=100-', 416, '', 'bytes */10'),
        ('bytes=-0', 416, '', 'bytes */10'),
      ]) {
        final response = await handler(
          RpcHttpRequest(
            method: 'GET',
            path: '/data.txt',
            headers: {'range': range},
          ),
        );
        expect(response.statusCode, status, reason: range);
        expect(response.headers['content-range'], contentRange);
        if (response.isStreaming)
          expect(
            await utf8.decodeStream(
              (response.content as RpcStreamingHttpBody).chunks,
            ),
            text,
          );
      }
      final stale = await handler(
        const RpcHttpRequest(
          method: 'GET',
          path: '/data.txt',
          headers: {'range': 'bytes=2-5', 'if-range': 'W/"stale"'},
        ),
      );
      expect(stale.statusCode, 200);
      expect(
        await utf8.decodeStream((stale.content as RpcStreamingHttpBody).chunks),
        '0123456789',
      );
    },
  );
}

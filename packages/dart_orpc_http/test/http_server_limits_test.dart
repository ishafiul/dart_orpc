import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  Future<Uri> serve(RpcHttpApp app) async {
    final server = await app.listen(
      0,
      hostname: InternetAddress.loopbackIPv4.address,
    );
    addTearDown(() => server.close(force: true));
    return Uri.parse('http://${server.address.address}:${server.port}');
  }

  HttpClient client() {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    return client;
  }

  RpcHttpApp echoApp({int? limit = 1024 * 1024, bool bytes = false}) =>
      RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: RestRouteRegistry([
          RestUnaryRoute(
            method: 'POST',
            path: '/echo',
            handler: (_, request, _) => {'body': request.body},
          ),
        ]),
        maxRequestBodyBytes: limit,
        encodeJsonToBytes: bytes,
      );

  group('request body buffering', () {
    test('fixed and chunked Unicode bodies work at exact byte limit', () async {
      const text = 'héllo বাংলা 🌍';
      final bytes = utf8.encode(text);
      final uri = await serve(echoApp(limit: bytes.length));
      final http = client();
      for (final fixedLength in [true, false]) {
        final request = await http.postUrl(uri.resolve('/echo'));
        if (fixedLength) request.contentLength = bytes.length;
        // Split inside multibyte UTF-8 characters as well as ASCII.
        await request.addStream(
          Stream.fromIterable(bytes.map((byte) => [byte])),
        );
        final response = await request.close();
        expect(response.statusCode, HttpStatus.ok);
        expect(jsonDecode(await utf8.decodeStream(response)), {'body': text});
      }
    });

    test(
      'announced and received-byte limits both reject oversized bodies',
      () async {
        final uri = await serve(echoApp(limit: 4));
        final http = client();
        for (final fixedLength in [true, false]) {
          final request = await http.postUrl(uri.resolve('/echo'));
          if (fixedLength) request.contentLength = 5;
          request.add([1, 2, 3, 4, 5]);
          final response = await request.close();
          expect(response.statusCode, HttpStatus.requestEntityTooLarge);
          expect(jsonDecode(await utf8.decodeStream(response)), {
            'error': {
              'code': 'PAYLOAD_TOO_LARGE',
              'message':
                  'Request body exceeds the maximum allowed size of 4 bytes.',
            },
          });
        }
      },
    );

    test(
      'empty bodies and disabled limits preserve response encoding',
      () async {
        final uri = await serve(echoApp(limit: null, bytes: true));
        final http = client();
        for (final body in ['', 'x' * (1024 * 1024 + 1)]) {
          final request = await http.postUrl(uri.resolve('/echo'));
          request.write(body);
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          expect(response.headers.contentType?.mimeType, 'application/json');
          expect(jsonDecode(await utf8.decodeStream(response)), {'body': body});
        }
      },
    );

    test(
      'flattened headers remain immutable with single and multiple values',
      () async {
        final uri = await serve(
          RpcHttpApp(
            procedures: RpcProcedureRegistry(const []),
            middleware: [
              (next) => (request) async {
                expect(
                  () => request.headers['x-single'] = 'changed',
                  throwsUnsupportedError,
                );
                return RpcHttpResponse(
                  statusCode: HttpStatus.ok,
                  body: jsonEncode(request.headers),
                );
              },
            ],
          ),
        );
        final http = client();
        final request = await http.getUrl(uri);
        request.headers.set('x-single', 'one');
        request.headers.add('x-many', 'one');
        request.headers.add('x-many', 'two');
        final response = await request.close();
        final headers =
            jsonDecode(await utf8.decodeStream(response))
                as Map<String, Object?>;
        expect(headers['x-single'], 'one');
        expect(
          (headers['x-many']! as String)
              .split(',')
              .map((value) => value.trim()),
          ['one', 'two'],
        );
      },
    );
  });

  group('admission limits', () {
    test('invalid limits fail at construction', () {
      for (final limit in [0, -1]) {
        expect(
          () => RpcHttpApp(
            procedures: RpcProcedureRegistry(const []),
            maxConcurrentRequests: limit,
          ),
          throwsArgumentError,
        );
      }
      for (final timeout in [Duration.zero, const Duration(seconds: -1)]) {
        expect(
          () => RpcHttpApp(
            procedures: RpcProcedureRegistry(const []),
            requestBodyIdleTimeout: timeout,
          ),
          throwsArgumentError,
        );
      }
    });

    test(
      'overload returns 503 and capacity recovers after completion and error',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        var calls = 0;
        final uri = await serve(
          RpcHttpApp(
            procedures: RpcProcedureRegistry(const []),
            maxConcurrentRequests: 1,
            middleware: [
              (next) => (request) async {
                calls++;
                if (request.path == '/hold') {
                  entered.complete();
                  await release.future;
                }
                if (request.path == '/error') throw StateError('failure');
                return const RpcHttpResponse(
                  statusCode: HttpStatus.ok,
                  body: 'ok',
                );
              },
            ],
          ),
        );
        addTearDown(() {
          if (!release.isCompleted) release.complete();
        });
        final http = client();
        final held = (await http.getUrl(uri.resolve('/hold'))).close();
        await entered.future;
        final rejected = await (await http.getUrl(
          uri.resolve('/other'),
        )).close();
        expect(rejected.statusCode, HttpStatus.serviceUnavailable);
        expect(jsonDecode(await utf8.decodeStream(rejected)), {
          'error': {
            'code': 'UNAVAILABLE',
            'message': 'Server has reached its concurrent request limit.',
          },
        });
        expect(calls, 1);
        release.complete();
        expect(await utf8.decodeStream(await held), 'ok');
        final failed = await (await http.getUrl(uri.resolve('/error'))).close();
        expect(failed.statusCode, HttpStatus.internalServerError);
        await failed.drain<void>();
        final recovered = await (await http.getUrl(uri.resolve('/ok'))).close();
        expect(recovered.statusCode, HttpStatus.ok);
        expect(await utf8.decodeStream(recovered), 'ok');
        expect(calls, 3);
      },
    );

    test(
      'stalled body returns 408, closes connection and releases capacity',
      () async {
        final uri = await serve(
          RpcHttpApp(
            procedures: RpcProcedureRegistry(const []),
            maxConcurrentRequests: 1,
            requestBodyIdleTimeout: const Duration(milliseconds: 50),
            middleware: [
              (next) =>
                  (_) async => const RpcHttpResponse(
                    statusCode: HttpStatus.ok,
                    body: 'ok',
                  ),
            ],
          ),
        );
        final socket = await Socket.connect(uri.host, uri.port);
        addTearDown(socket.destroy);
        final response = utf8.decodeStream(socket);
        socket.write(
          'POST /stall HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n1\r\nx\r\n',
        );
        await socket.flush();
        final raw = await response.timeout(const Duration(seconds: 5));
        expect(raw, startsWith('HTTP/1.1 408'));
        expect(raw, contains('REQUEST_TIMEOUT'));
        final http = client();
        final recovered = await (await http.getUrl(uri.resolve('/ok'))).close();
        expect(recovered.statusCode, HttpStatus.ok);
        expect(await utf8.decodeStream(recovered), 'ok');
      },
    );
  });

  test(
    'static files stream through CORS with correct content length',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'orpc-http-static',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bytes = List<int>.generate(256 * 1024, (index) => index % 256);
      await File('${directory.path}/large.bin').writeAsBytes(bytes);
      final uri = await serve(
        RpcHttpApp(
          procedures: RpcProcedureRegistry(const []),
          staticAssets: RpcHttpStaticOptions(directory: directory.path),
          middleware: [createCorsMiddleware()],
        ),
      );
      final http = client();
      final response = await (await http.getUrl(
        uri.resolve('/large.bin'),
      )).close();
      expect(response.statusCode, HttpStatus.ok);
      expect(response.contentLength, bytes.length);
      expect(response.headers.chunkedTransferEncoding, isFalse);
      expect(response.headers.value('access-control-allow-origin'), '*');
      final etag = response.headers.value('etag')!;
      expect(await response.expand((chunk) => chunk).toList(), bytes);
      final conditional = await http.getUrl(uri.resolve('/large.bin'));
      conditional.headers.set('if-none-match', etag);
      final unchanged = await conditional.close();
      expect(unchanged.statusCode, HttpStatus.notModified);
      expect(await unchanged.expand((chunk) => chunk).toList(), isEmpty);
    },
  );

  test('buffered SSE preserves complete ordered events through CORS', () async {
    final uri = await serve(
      RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: RestRouteRegistry([
          RestStreamRoute(
            path: '/events',
            handler: (_, _, _) => Stream.fromIterable([1, 2, 3]),
          ),
        ]),
        sseHeartbeatInterval: Duration.zero,
        sseFlushEachChunk: false,
        middleware: [createCorsMiddleware()],
      ),
    );
    final http = client();
    final response = await (await http.getUrl(uri.resolve('/events'))).close();
    expect(response.headers.contentType?.mimeType, 'text/event-stream');
    expect(
      await utf8.decodeStream(response),
      'data: 1\n\ndata: 2\n\ndata: 3\n\nevent: dart-orpc-complete\ndata: {}\n\n',
    );
  });
}

/// Behaviour every `HttpServer` used by dart_orpc must share.
///
/// The same suite runs against `dart:io` (the reference) and against
/// `RustHttpServer`. A test that passes on one and fails on the other is a
/// parity bug.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Binds a server on `127.0.0.1`, by default on any free port.
typedef ServerBinder = Future<HttpServer> Function({int port, bool shared});

/// Accepts a WebSocket upgrade of a request.
typedef WebSocketUpgrader = Future<WebSocket> Function(
  HttpRequest request, {
  Object? Function(List<String> protocols)? protocolSelector,
});

/// Registers the contract tests for one server implementation.
void runHttpServerContract({
  required String name,
  required ServerBinder bind,
  required WebSocketUpgrader upgradeWebSocket,
}) {
  group('$name contract', () {
    late HttpServer server;
    late HttpClient client;
    late void Function(HttpRequest request) handler;

    setUp(() async {
      server = await bind();
      server.listen((request) => handler(request));
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    Future<HttpClientResponse> send(
      String method,
      String path, {
      Map<String, String> headers = const {},
      List<int>? body,
      bool chunked = false,
    }) async {
      final request = await client.open(method, '127.0.0.1', server.port, path);
      headers.forEach(request.headers.set);
      if (chunked) {
        request.headers.chunkedTransferEncoding = true;
      } else if (body != null) {
        request.contentLength = body.length;
      }
      if (body != null) request.add(body);
      return request.close();
    }

    Future<List<int>> readAll(HttpClientResponse response) async {
      final bytes = <int>[];
      await response.forEach(bytes.addAll);
      return bytes;
    }

    group('requests', () {
      test('expose method, uri, headers, cookies and connection', () async {
        final seen = Completer<Map<String, Object?>>();
        handler = (request) {
          seen.complete({
            'method': request.method,
            'path': request.uri.path,
            'query': request.uri.queryParameters,
            'header': request.headers.value('x-test'),
            'cookies': [
              for (final c in request.cookies) '${c.name}=${c.value}',
            ],
            'protocol': request.protocolVersion,
            'persistent': request.persistentConnection,
            'loopback': request.connectionInfo?.remoteAddress.isLoopback,
            'host': request.requestedUri.host,
            'port': request.requestedUri.port,
          });
          unawaited(request.response.close());
        };

        await readAll(
          await send(
            'GET',
            '/a/b?x=1&y=two',
            headers: {'x-test': 'yes', 'cookie': 'k=v; m=n'},
          ),
        );

        expect(await seen.future, {
          'method': 'GET',
          'path': '/a/b',
          'query': {'x': '1', 'y': 'two'},
          'header': 'yes',
          'cookies': ['k=v', 'm=n'],
          'protocol': '1.1',
          'persistent': true,
          'loopback': true,
          'host': '127.0.0.1',
          'port': server.port,
        });
      });

      test('deliver a body with its content length', () async {
        final body = List<int>.generate(1000, (i) => i % 256);
        handler = (request) async {
          final length = request.contentLength;
          final received = <int>[];
          await request.forEach(received.addAll);
          request.response
            ..headers.set('x-length', '$length')
            ..add(received);
          await request.response.close();
        };

        final response = await send('POST', '/', body: body);

        expect(response.headers.value('x-length'), '1000');
        expect(await readAll(response), body);
      });

      test('deliver a chunked body', () async {
        final body = utf8.encode('chunked body ' * 100);
        handler = (request) async {
          final received = <int>[];
          await request.forEach(received.addAll);
          request.response.add(received);
          await request.response.close();
        };

        final response = await send('POST', '/', body: body, chunked: true);

        expect(await readAll(response), body);
      });
    });

    group('responses', () {
      test('carry the dart:io default headers', () async {
        handler = (request) {
          request.response.write('Hello World');
          unawaited(request.response.close());
        };

        final response = await send('GET', '/');

        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.contentType?.mimeType, 'text/plain');
        expect(response.headers.contentType?.charset, 'utf-8');
        expect(response.headers.value('x-content-type-options'), 'nosniff');
        expect(response.headers.value('x-frame-options'), 'SAMEORIGIN');
        expect(utf8.decode(await readAll(response)), 'Hello World');
      });

      test('carry status, set and added headers, and cookies', () async {
        handler = (request) {
          request.response
            ..statusCode = HttpStatus.created
            ..headers.set('x-one', 'a')
            ..headers.add('x-many', 'b')
            ..headers.add('x-many', 'c')
            ..cookies.add(Cookie('session', 'abc'))
            ..cookies.add(Cookie('theme', 'dark'));
          unawaited(request.response.close());
        };

        final response = await send('GET', '/');

        expect(response.statusCode, HttpStatus.created);
        expect(response.headers.value('x-one'), 'a');
        expect(
          response.headers['x-many']
              ?.expand((v) => v.split(','))
              .map((v) => v.trim()),
          ['b', 'c'],
        );
        expect(
          {for (final c in response.cookies) c.name: c.value},
          {'session': 'abc', 'theme': 'dark'},
        );
      });

      test('send no body for HEAD', () async {
        handler = (request) {
          request.response.write('ignored');
          unawaited(request.response.close());
        };

        final response = await send('HEAD', '/');

        expect(response.statusCode, HttpStatus.ok);
        expect(await readAll(response), isEmpty);
      });

      test('send no body for 204 and keep the connection', () async {
        handler = (request) {
          request.response
            ..statusCode = request.uri.path == '/empty'
                ? HttpStatus.noContent
                : HttpStatus.ok
            ..contentLength = request.uri.path.length
            ..write(request.uri.path);
          unawaited(request.response.close());
        };

        final reply = await _rawExchange(
          server.port,
          'GET /empty HTTP/1.1\r\nHost: x\r\n\r\n'
          'GET /next HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
        );

        expect(reply, contains('HTTP/1.1 204'));
        expect(reply, contains('HTTP/1.1 200'));
        expect(reply, endsWith('/next'));
      });

      test('answer pipelined requests in order', () async {
        handler = (request) {
          request.response
            ..contentLength = request.uri.path.length
            ..write(request.uri.path);
          unawaited(request.response.close());
        };

        final reply = await _rawExchange(
          server.port,
          'GET /1 HTTP/1.1\r\nHost: x\r\n\r\n'
          'GET /2 HTTP/1.1\r\nHost: x\r\n\r\n'
          'GET /3 HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n',
        );

        final bodies = RegExp(r'\r\n\r\n(/\d)').allMatches(reply);
        expect([for (final m in bodies) m[1]], ['/1', '/2', '/3']);
      });

      test('close the connection when not persistent', () async {
        handler = (request) {
          request.response
            ..persistentConnection = false
            ..contentLength = 3
            ..write('bye');
          unawaited(request.response.close());
        };

        final reply = await _rawExchange(
          server.port,
          'GET / HTTP/1.1\r\nHost: x\r\n\r\n',
        );

        expect(reply.toLowerCase(), contains('connection: close'));
        expect(reply, endsWith('bye'));
      });

      test('redirect', () async {
        handler = (request) {
          unawaited(request.response.redirect(Uri.parse('/elsewhere')));
        };
        client.autoUncompress = false;

        final request = await client.get('127.0.0.1', server.port, '/');
        request.followRedirects = false;
        final response = await request.close();

        expect(response.statusCode, HttpStatus.movedTemporarily);
        expect(response.headers.value('location'), '/elsewhere');
      });

      test('use the server header and default headers', () async {
        server
          ..serverHeader = 'contract'
          ..defaultResponseHeaders.set('x-default', 'yes');
        handler = (request) => unawaited(request.response.close());

        final response = await send('GET', '/');

        expect(response.headers.value('server'), 'contract');
        expect(response.headers.value('x-default'), 'yes');
      });

      test('gzip a body when autoCompress is on', () async {
        server.autoCompress = true;
        final text = 'compress me ' * 200;
        handler = (request) {
          request.response.write(text);
          unawaited(request.response.close());
        };
        client.autoUncompress = false;

        final response = await send(
          'GET',
          '/',
          headers: {'accept-encoding': 'gzip'},
        );

        expect(response.headers.value('content-encoding'), 'gzip');
        expect(utf8.decode(gzip.decode(await readAll(response))), text);
      });
    });

    group('streaming', () {
      test('deliver each chunk at once when bufferOutput is false', () async {
        final clientGotFirst = Completer<void>();
        handler = (request) async {
          final response = request.response
            ..bufferOutput = false
            ..headers.contentType = ContentType('text', 'event-stream');
          final chunks = StreamController<List<int>>();
          final sending = response.addStream(chunks.stream);
          chunks.add(utf8.encode('data: 1\n\n'));
          await clientGotFirst.future;
          chunks.add(utf8.encode('data: 2\n\n'));
          await chunks.close();
          await sending;
          await response.close();
        };

        final response = await send('GET', '/events');
        final received = StringBuffer();
        await for (final chunk in response) {
          received.write(utf8.decode(chunk));
          if (!clientGotFirst.isCompleted) clientGotFirst.complete();
        }

        expect(received.toString(), 'data: 1\n\ndata: 2\n\n');
      }, timeout: const Timeout(Duration(seconds: 5)));

      test('a zero deadline cuts a started response', () async {
        handler = (request) async {
          // The deadline, not close(), ends this response.
          // ignore: close_sinks
          final response = request.response..bufferOutput = false;
          response.write('partial');
          await response.flush();
          response.deadline = Duration.zero;
        };

        final response = await send('GET', '/');

        await expectLater(readAll(response), throwsA(isA<HttpException>()));
      }, timeout: const Timeout(Duration(seconds: 5)));
    });

    group('lifecycle', () {
      test('an unshared port cannot be bound again', () async {
        await expectLater(
          bind(port: server.port, shared: true),
          throwsA(isA<SocketException>()),
        );
      });

      test('a shared port can be bound by several servers', () async {
        final first = await bind(shared: true);
        addTearDown(() => first.close(force: true));
        final second = await bind(port: first.port, shared: true);
        addTearDown(() => second.close(force: true));

        expect(second.port, first.port);
      });

      test('report the bound port and a loopback address', () {
        expect(server.port, greaterThan(0));
        expect(server.address.isLoopback, isTrue);
      });

      test('a graceful close lets an open request finish', () async {
        final started = Completer<void>();
        final release = Completer<void>();
        handler = (request) async {
          started.complete();
          await release.future;
          request.response.write('finished');
          await request.response.close();
        };

        final pending = send('GET', '/');
        await started.future;
        final closing = server.close();
        release.complete();

        expect(utf8.decode(await readAll(await pending)), 'finished');
        await closing;
      });

      test('a forced close cuts an open request', () async {
        final started = Completer<void>();
        handler = (_) => started.complete();

        final pending = send('GET', '/').then(readAll);
        await started.future;
        await server.close(force: true);

        await expectLater(pending, throwsA(anything));
      });
    });

    group('WebSocket', () {
      test('a reply sent later and a close during shutdown arrive', () async {
        handler = (request) async {
          final socket = await upgradeWebSocket(request);
          await for (final message in socket) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            socket.add('later: $message');
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await socket.close(WebSocketStatus.goingAway, 'shutdown');
          }
        };

        // The server closes this socket.
        // ignore: close_sinks
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:${server.port}/ws',
        );
        final replies = <Object?>[];
        final done = socket.forEach(replies.add);
        socket.add('hi');
        await done.timeout(const Duration(seconds: 3));

        expect(replies, ['later: hi']);
        expect(socket.closeCode, WebSocketStatus.goingAway);
      });

      test('a graceful close leaves open WebSockets to the app', () async {
        final accepted = Completer<WebSocket>();
        handler = (request) async {
          final socket = await upgradeWebSocket(request);
          accepted.complete(socket);
          await for (final message in socket) {
            socket.add('echo: $message');
          }
        };

        final client = await WebSocket.connect(
          'ws://127.0.0.1:${server.port}/ws',
        );
        addTearDown(client.close);
        final replies = StreamIterator<Object?>(client);
        final serverSide = await accepted.future;
        await server.close().timeout(const Duration(seconds: 3));
        client.add('after close');

        expect(await replies.moveNext(), isTrue);
        expect(replies.current, 'echo: after close');
        await serverSide.close(WebSocketStatus.normalClosure);
        expect(await replies.moveNext(), isFalse);
        expect(client.closeCode, WebSocketStatus.normalClosure);
      });

      test('the protocol selector picks the subprotocol', () async {
        final offered = Completer<List<String>>();
        handler = (request) async {
          final socket = await upgradeWebSocket(
            request,
            protocolSelector: (protocols) {
              offered.complete(protocols);
              return 'b';
            },
          );
          await socket.close();
        };

        // The server closes this socket.
        // ignore: close_sinks
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:${server.port}/ws',
          protocols: ['a', 'b'],
        );
        await socket.drain<void>();

        expect(await offered.future, ['a', 'b']);
        expect(socket.protocol, 'b');
      });

      test('echoes text and binary and reports the close code', () async {
        handler = (request) async {
          final socket = await upgradeWebSocket(request);
          await for (final message in socket) {
            if (message == 'bye') {
              await socket.close(WebSocketStatus.goingAway, 'done');
            } else {
              socket.add(message);
            }
          }
        };

        // The server closes this socket.
        // ignore: close_sinks
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:${server.port}/ws',
        );
        final replies = <Object?>[];
        final done = socket.forEach(replies.add);
        socket
          ..add('hello')
          ..add([1, 2, 3])
          ..add('bye');
        await done;

        expect(replies, [
          'hello',
          [1, 2, 3],
        ]);
        expect(socket.closeCode, WebSocketStatus.goingAway);
        expect(socket.closeReason, 'done');
      });
    });
  });
}

/// Writes [request] on a fresh socket and reads until the server closes.
Future<String> _rawExchange(int port, String request) async {
  final socket = await Socket.connect('127.0.0.1', port);
  socket.write(request);
  await socket.flush();
  final reply = StringBuffer();
  await socket
      .cast<List<int>>()
      .transform(latin1.decoder)
      .forEach(reply.write)
      .timeout(const Duration(seconds: 5));
  socket.destroy();
  return reply.toString();
}

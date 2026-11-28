/// Behaviour every `HttpServer` must share on a Unix domain socket.
///
/// The same suite runs against `dart:io` (the reference) and against
/// `RustHttpServer`. A test that passes on one and fails on the other is a
/// parity bug.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Binds a server on the Unix domain socket [address].
typedef UnixServerBinder = Future<HttpServer> Function(
  InternetAddress address, {
  bool shared,
});

/// Accepts a WebSocket upgrade of a request.
typedef UnixWebSocketUpgrader = Future<WebSocket> Function(HttpRequest request);

/// Registers the Unix domain socket contract tests for one server.
void runUnixSocketContract({
  required String name,
  required UnixServerBinder bind,
  required UnixWebSocketUpgrader upgradeWebSocket,
}) {
  group('$name Unix domain socket contract', () {
    late Directory directory;
    late InternetAddress address;
    var count = 0;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('rh_unix_');
      // Short names: a socket path has a limit of about 100 bytes.
      address = InternetAddress(
        '${directory.path}/s${count++}',
        type: InternetAddressType.unix,
      );
    });

    tearDown(() => directory.delete(recursive: true));

    HttpClient clientFor(InternetAddress socket) =>
        HttpClient()
          ..connectionFactory = (uri, proxyHost, proxyPort) =>
              Socket.startConnect(socket, 0);

    Future<(int, String)> get(
      HttpClient client,
      String path, {
      String method = 'GET',
      List<int>? body,
    }) async {
      final request = await client.open(method, 'localhost', 80, path);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close();
      return (response.statusCode, await utf8.decodeStream(response));
    }

    test('reports the path as its address and port 0', () async {
      final server = await bind(address);
      addTearDown(() => server.close(force: true));

      expect(server.address.type, InternetAddressType.unix);
      expect(server.address.address, address.address);
      expect(server.port, 0);
      expect(
        FileSystemEntity.typeSync(address.address),
        FileSystemEntityType.unixDomainSock,
      );
    });

    test('answers requests, keeps connections alive and streams', () async {
      final server = await bind(address);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final body = await utf8.decodeStream(request);
        if (request.uri.path == '/stream') {
          request.response
            ..write('a')
            ..write('b');
          await request.response.flush();
          request.response.write('c');
        } else {
          request.response.write('${request.method} ${request.uri} $body');
        }
        await request.response.close();
      });
      final client = clientFor(address);
      addTearDown(() => client.close(force: true));

      expect(await get(client, '/one?x=1'), (200, 'GET /one?x=1 '));
      expect(
        await get(client, '/two', method: 'POST', body: utf8.encode('hi')),
        (200, 'POST /two hi'),
      );
      expect(await get(client, '/stream'), (200, 'abc'));
    });

    test('reports peers like dart:io: no address, port 0', () async {
      final server = await bind(address);
      addTearDown(() => server.close(force: true));
      final seen = Completer<List<Object?>>();
      server.listen((request) {
        final info = request.connectionInfo;
        seen.complete([
          info?.remoteAddress.type,
          info?.remoteAddress.address,
          info?.remotePort,
          info?.localPort,
          request.requestedUri.toString(),
        ]);
        unawaited(request.response.close());
      });
      final client = clientFor(address);
      addTearDown(() => client.close(force: true));

      await get(client, '/who');

      expect(await seen.future, [
        InternetAddressType.unix,
        '',
        0,
        0,
        'http://localhost/who',
      ]);
    });

    test('upgrades a WebSocket', () async {
      final server = await bind(address);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final socket = await upgradeWebSocket(request);
        await for (final message in socket) {
          socket.add('echo $message');
        }
        await socket.close();
      });
      // By hand: dart:io's client WebSocket cannot run over a Unix domain
      // socket (fromUpgradedSocket parses the peer path as a URI).
      final socket = await Socket.connect(address, 0);
      addTearDown(socket.destroy);
      final received = <int>[];
      final more = StreamController<void>.broadcast();
      socket.listen((data) {
        received.addAll(data);
        more.add(null);
      });
      Future<void> until(bool Function() done) async {
        while (!done()) {
          await more.stream.first.timeout(const Duration(seconds: 5));
        }
      }

      socket.write(
        'GET /ws HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\n'
        'Connection: Upgrade\r\nSec-WebSocket-Version: 13\r\n'
        'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n\r\n',
      );
      await until(() => latin1.decode(received).contains('\r\n\r\n'));
      final head = latin1.decode(received);
      expect(head, startsWith('HTTP/1.1 101'));
      expect(head.toLowerCase(), contains('s3pplmbitxaq9kygzzhzrbk+xoo='));
      received.removeRange(0, head.indexOf('\r\n\r\n') + 4);

      // A masked text frame "ping"; the mask key is 1, 2, 3, 4.
      const mask = [1, 2, 3, 4];
      final payload = utf8.encode('ping');
      socket.add([
        0x81,
        0x80 | payload.length,
        ...mask,
        for (var i = 0; i < payload.length; i++) payload[i] ^ mask[i % 4],
      ]);
      await until(
        () => received.length >= 2 && received.length >= 2 + received[1],
      );

      expect(received[0], 0x81);
      expect(utf8.decode(received.sublist(2, 2 + received[1])), 'echo ping');
      await more.close();
    });

    test('removes the socket file on close', () async {
      final server = await bind(address);

      await server.close();

      expect(
        FileSystemEntity.typeSync(address.address),
        FileSystemEntityType.notFound,
      );
    });

    test('refuses a path that exists, and keeps the file', () async {
      File(address.address).writeAsStringSync('not a socket');

      await expectLater(bind(address), throwsA(isA<SocketException>()));
      expect(File(address.address).readAsStringSync(), 'not a socket');
    });

    test('refuses a second bind of a path unless both are shared', () async {
      final first = await bind(address);
      addTearDown(() => first.close(force: true));

      await expectLater(bind(address), throwsA(isA<SocketException>()));
      await expectLater(
        bind(address, shared: true),
        throwsA(isA<SocketException>()),
      );
    });

    test('lets shared binds share a path; the last close removes it', () async {
      final first = await bind(address, shared: true);
      final second = await bind(address, shared: true);
      final answered = <String>[];
      for (final (name, server) in [('first', first), ('second', second)]) {
        server.listen((request) {
          answered.add(name);
          request.response.write(name);
          unawaited(request.response.close());
        });
      }
      final client = clientFor(address);
      addTearDown(() => client.close(force: true));

      expect((await get(client, '/')).$1, 200);
      await first.close(force: true);
      expect(
        FileSystemEntity.typeSync(address.address),
        FileSystemEntityType.unixDomainSock,
      );
      client.close(force: true);
      final again = clientFor(address);
      addTearDown(() => again.close(force: true));
      expect(await get(again, '/'), (200, 'second'));
      await second.close(force: true);
      expect(
        FileSystemEntity.typeSync(address.address),
        FileSystemEntityType.notFound,
      );
      expect(answered, isNotEmpty);
    });
  });
}

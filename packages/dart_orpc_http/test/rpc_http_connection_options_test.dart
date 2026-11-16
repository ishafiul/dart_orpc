import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  Future<RpcHttpServer> serve(RpcHttpServerOptions options) async {
    final server = await RpcHttpApp(
      procedures: RpcProcedureRegistry(const []),
      serverOptions: options,
    ).listen(0, hostname: '127.0.0.1');
    addTearDown(() => server.close(force: true));
    return server;
  }

  /// A keep-alive connection that has had one request answered.
  Future<Socket> answeredConnection(RpcHttpServer server) async {
    final socket = await Socket.connect('127.0.0.1', server.port);
    addTearDown(socket.destroy);
    socket.write('GET /missing HTTP/1.1\r\nHost: x\r\n\r\n');
    await socket.flush();
    return socket;
  }

  /// Completes when the server closes [socket]; times out otherwise.
  Future<void> closedBy(Socket socket, Duration within) =>
      socket.drain<void>().timeout(within);

  group('Given RpcHttpServerOptions.idleTimeout', () {
    test(
      'When a keep-alive connection idles past it Then the server closes it',
      () async {
        final server = await serve(
          const RpcHttpServerOptions(idleTimeout: Duration(milliseconds: 300)),
        );
        final socket = await answeredConnection(server);

        await closedBy(socket, const Duration(seconds: 3));
      },
    );

    test(
      'When it is not set Then an idle connection stays open longer',
      () async {
        final server = await serve(const RpcHttpServerOptions());
        final socket = await answeredConnection(server);

        await expectLater(
          closedBy(socket, const Duration(seconds: 1)),
          throwsA(isA<TimeoutException>()),
        );
      },
    );

    test('When it is not positive Then listen refuses it', () async {
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        serverOptions: const RpcHttpServerOptions(idleTimeout: Duration.zero),
      );

      await expectLater(
        app.listen(0, hostname: '127.0.0.1'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Given RpcHttpServerOptions.maxConnections', () {
    test('When the limit is reached Then another client waits until a connection closes', () async {
      final server = await serve(const RpcHttpServerOptions(maxConnections: 1));
      final first = await answeredConnection(server);
      final firstAnswer = first
          .cast<List<int>>()
          .transform(latin1.decoder)
          .first;
      expect(await firstAnswer, startsWith('HTTP/1.1 404'));

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final second = client
          .get('127.0.0.1', server.port, '/missing')
          .then((request) => request.close())
          .then((response) => response.statusCode);
      await expectLater(
        second.timeout(const Duration(milliseconds: 500)),
        throwsA(isA<TimeoutException>()),
      );

      first.destroy();

      expect(
        await second.timeout(const Duration(seconds: 5)),
        HttpStatus.notFound,
      );
    });
  });
}

@TestOn('mac-os || linux')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  late String path;

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('orpc_unix_');
    addTearDown(() => directory.delete(recursive: true));
    // Short: a socket path has a limit of about 100 bytes.
    path = '${directory.path}/app.sock';
  });

  HttpClient clientFor(String socketPath) {
    final client = HttpClient()
      ..connectionFactory = (uri, proxyHost, proxyPort) => Socket.startConnect(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
    addTearDown(() => client.close(force: true));
    return client;
  }

  Future<(int, Object?)> call(
    HttpClient client,
    String method,
    String target, [
    String? body,
  ]) async {
    final request = await client.open(method, 'localhost', 80, target);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close();
    return (response.statusCode, jsonDecode(await utf8.decodeStream(response)));
  }

  group('RpcHttpApp.listenUnix', () {
    test('serves RPC and REST on the socket and removes it on close', () async {
      final server = await _createApp().listenUnix(path);

      expect(server.port, 0);
      expect(server.address.type, InternetAddressType.unix);
      expect(server.address.address, path);
      final client = clientFor(path);
      final (status, body) = await call(
        client,
        'POST',
        '/rpc',
        '{"method":"test.echo"}',
      );
      expect(status, 200);
      expect(body, {'data': 'ready'});
      expect(
        (await call(client, 'GET', '/items/7')).$2,
        containsPair('id', '7'),
      );

      await server.close();

      expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound);
    });

    test('reports the socket path and http+unix URLs to observers', () async {
      final observer = _RecordingObserver();
      final server = await _createApp(observer: observer).listenUnix(path);
      addTearDown(() => server.close(force: true));

      final started = observer.started.single;
      expect(started.host, path);
      expect(started.port, 0);
      final urls = {for (final e in started.endpoints) e.name: e.url};
      expect(urls.keys.first, 'socket');
      expect(urls['socket']!.scheme, 'unix');
      expect(urls['socket']!.path, path);
      expect('${urls['rpc']}', 'http://localhost/rpc');
    });

    test('refuses a path that already exists', () async {
      File(path).writeAsStringSync('');

      await expectLater(
        _createApp().listenUnix(path),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('RpcHttpIsolateServer with unixSocketPath', () {
    test('every worker serves the one socket', () async {
      final server = await RpcHttpIsolateServer.start(
        createApp: _createApp,
        port: 0,
        workers: 2,
        unixSocketPath: path,
      );
      addTearDown(() => server.close(force: true).catchError((Object _) {}));

      expect(server.port, 0);
      expect(server.address.type, InternetAddressType.unix);
      expect(server.address.address, path);
      final workers = <Object?>{};
      for (var index = 0; index < 16; index++) {
        // A new connection each time, so the OS can pick either worker.
        final client = clientFor(path);
        final (status, body) = await call(client, 'GET', '/items/$index');
        expect(status, 200);
        workers.add((body! as Map)['worker']);
        client.close(force: true);
      }
      expect(
        workers,
        everyElement(isIn(['dart-orpc-http-0', 'dart-orpc-http-1'])),
      );

      await server.close();

      expect(FileSystemEntity.typeSync(path), FileSystemEntityType.notFound);
    });
  });
}

RpcHttpApp _createApp({RpcObserver? observer}) => RpcHttpApp(
  observer: observer,
  procedures: RpcProcedureRegistry([
    RpcUnaryProcedure<Null, String>(
      method: 'test.echo',
      metadata: const ProcedureMetadata(
        rpcMethod: 'test.echo',
        controllerNamespace: 'test',
        methodName: 'echo',
        outputTypeCode: 'String',
      ),
      decodeInput: (_) => null,
      encodeOutput: (value) => value,
      handler: (_, _) => 'ready',
    ),
  ]),
  restRoutes: RestRouteRegistry([
    RestUnaryRoute(
      method: 'GET',
      path: '/items/:id',
      handler: (_, _, parameters) => {
        ...parameters,
        'worker': Isolate.current.debugName,
      },
    ),
  ]),
);

final class _RecordingObserver implements RpcObserver {
  final List<RpcObservedServer> started = [];

  @override
  RpcCallObservation startCall(RpcObservedCallStart start) =>
      const _NoObservation();

  @override
  void serverStarted(RpcObservedServer server) => started.add(server);

  @override
  void serverStopped(RpcObservedServer server) {}

  @override
  Future<void> close() async {}
}

final class _NoObservation implements RpcCallObservation {
  const _NoObservation();

  @override
  void identify(String rpcMethod) {}

  @override
  void recordError(Object error, StackTrace stackTrace) {}

  @override
  void end(RpcObservedCallEnd end) {}
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  Future<RpcHttpIsolateServer> start({
    FutureOr<RpcHttpApp> Function() createApp = _createApp,
    int workers = 2,
    int port = 0,
    FutureOr<void> Function(RpcHttpApp)? disposeApp,
  }) async {
    final server = await RpcHttpIsolateServer.start(
      createApp: createApp,
      workers: workers,
      hostname: '127.0.0.1',
      port: port,
      disposeApp: disposeApp,
    );
    addTearDown(() => server.close(force: true).catchError((Object _) {}));
    return server;
  }

  HttpClient client() {
    final http = HttpClient();
    addTearDown(() => http.close(force: true));
    return http;
  }

  test(
    'workers serve generated-style RPC and REST on one ephemeral port',
    () async {
      final server = await start();
      expect(server.workerCount, 2);
      expect(server.port, greaterThan(0));
      final base = Uri.parse('http://${server.address.address}:${server.port}');
      final http = client();
      for (var index = 0; index < 8; index++) {
        final request = await http.getUrl(base.resolve('/items/$index'));
        request.persistentConnection = false;
        final response = await request.close();
        expect(response.statusCode, 200);
        final body = jsonDecode(await utf8.decodeStream(response)) as Map;
        expect(body['id'], '$index');
        expect(body['worker'], isIn(['dart-orpc-http-0', 'dart-orpc-http-1']));
      }
      final rpc = await http.postUrl(base.resolve('/rpc'));
      rpc.headers.contentType = ContentType.json;
      rpc.write('{"method":"test.echo"}');
      final response = await rpc.close();
      expect(response.statusCode, 200);
      expect(jsonDecode(await utf8.decodeStream(response)), {'data': 'ready'});
      final closing = server.close();
      expect(server.close(), same(closing));
      await closing;
      await server.done;
      // Every worker released the shared listener.
      final rebound = await ServerSocket.bind('127.0.0.1', server.port);
      await rebound.close();
    },
  );

  test('startup failure closes workers already bound to shared port', () async {
    final reservation = await ServerSocket.bind('127.0.0.1', 0);
    final port = reservation.port;
    await reservation.close();
    await expectLater(
      start(createApp: _partiallyFailingApp, port: port),
      throwsA(
        isA<RemoteError>().having(
          (error) => error.toString(),
          'message',
          contains('factory failed'),
        ),
      ),
    );
    final rebound = await ServerSocket.bind('127.0.0.1', port);
    await rebound.close();
  });

  test('startup timeout terminates stuck factory', () async {
    await expectLater(
      RpcHttpIsolateServer.start(
        createApp: _stuckFactory,
        port: 0,
        hostname: '127.0.0.1',
        workers: 1,
        startupTimeout: const Duration(milliseconds: 100),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'uncaught async startup errors fail promptly without waiting for timeout',
    () async {
      await expectLater(
        start(createApp: _asyncFailingFactory, workers: 1),
        throwsA(isA<RemoteError>()),
      );
    },
  );

  test(
    'unsendable factory captures fail without leaking supervisor ports',
    () async {
      final resource = ReceivePort();
      addTearDown(resource.close);
      await expectLater(
        start(createApp: _unsendableFactory(resource), workers: 1),
        throwsArgumentError,
      );
    },
  );

  test('binding failure disposes app created inside worker', () async {
    final occupied = await ServerSocket.bind('127.0.0.1', 0);
    addTearDown(occupied.close);
    final events = ReceivePort();
    addTearDown(events.close);
    final disposed = events.first;
    await expectLater(
      start(
        port: occupied.port,
        workers: 1,
        disposeApp: _disposer(events.sendPort),
      ),
      throwsA(isA<RemoteError>()),
    );
    expect(await disposed, 'disposed');
  });

  test(
    'unexpected VM exit during startup is reported and cleaned up',
    () async {
      await expectLater(
        start(createApp: _exitingFactory, workers: 1),
        throwsA(isA<RemoteError>()),
      );
    },
  );

  test('VM errors outside app zone propagate through startup', () async {
    await expectLater(
      start(createApp: _vmFailingFactory, workers: 1),
      throwsA(isA<RemoteError>()),
    );
  });

  test('worker crash fails done and closes remaining workers', () async {
    final server = await start();
    final failed = expectLater(server.done, throwsA(isA<RemoteError>()));
    final http = client();
    final request = await http.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/crash'),
    );
    final response = request.close().then<void>(
      (response) => response.drain<void>(),
      onError: (Object _) {},
    );
    await failed.timeout(const Duration(seconds: 5));
    http.close(force: true);
    await response;
    final rebound = await ServerSocket.bind('127.0.0.1', server.port);
    await rebound.close();
  });

  test('shutdown drains request before disposing app in each worker', () async {
    final events = ReceivePort();
    addTearDown(events.close);
    final messages = _events(events);
    final server = await start(
      createApp: _controlledFactory(events.sendPort),
      workers: 1,
      disposeApp: _disposer(events.sendPort),
    );
    final entered = messages
        .firstWhere((event) => event is SendPort)
        .then((event) => event as SendPort);
    final disposed = messages.firstWhere((event) => event == 'disposed');
    final request = await client().getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/wait'),
    );
    final responseFuture = request.close();
    final release = await entered;
    final closing = server.close(gracePeriod: const Duration(seconds: 3));
    release.send(null);
    final response = await responseFuture;
    expect(response.statusCode, 200);
    expect(jsonDecode(await utf8.decodeStream(response)), 'finished');
    await closing;
    await disposed;
  });

  test(
    'forced shutdown cancels active requests and disposes every app',
    () async {
      final events = ReceivePort();
      addTearDown(events.close);
      final messages = _events(events);
      final disposed = messages
          .where((event) => event == 'disposed')
          .take(2)
          .toList();
      final entered = messages.firstWhere((event) => event is SendPort);
      final server = await start(
        createApp: _controlledFactory(events.sendPort),
        disposeApp: _disposer(events.sendPort),
      );
      final request = await client().getUrl(
        Uri.parse('http://127.0.0.1:${server.port}/wait'),
      );
      final response = request.close().then<void>(
        (response) => response.drain<void>(),
        onError: (Object _) {},
      );
      await entered;
      await server.close(force: true);
      await disposed;
      await response;
      await server.done;
    },
  );

  test(
    'unresponsive cleanup has bounded shutdown and reports failure',
    () async {
      final events = ReceivePort();
      addTearDown(events.close);
      final messages = events.asBroadcastStream();
      final disposed = messages.firstWhere(
        (event) => event == 'cleanup entered',
      );
      final server = await start(
        workers: 1,
        disposeApp: _stuckDisposer(events.sendPort),
      );
      final failed = expectLater(server.done, throwsA(isA<TimeoutException>()));
      final closing = server.close(force: true);
      await disposed;
      await expectLater(closing, throwsA(isA<TimeoutException>()));
      await failed;
    },
  );

  test(
    'negative shutdown grace period fails without closing workers',
    () async {
      final server = await start(workers: 1);
      expect(
        () => server.close(gracePeriod: const Duration(seconds: -1)),
        throwsArgumentError,
      );
      await server.close();
    },
  );

  test('cleanup errors propagate through close and done', () async {
    final server = await start(workers: 1, disposeApp: _failingDispose);
    final failed = expectLater(server.done, throwsA(isA<RemoteError>()));
    await expectLater(server.close(), throwsA(isA<RemoteError>()));
    await failed;
  });

  test(
    'invalid worker counts, ports and startup deadlines fail before spawning',
    () async {
      for (final count in [0, -1]) {
        await expectLater(
          RpcHttpIsolateServer.start(
            createApp: _createApp,
            port: 0,
            workers: count,
          ),
          throwsArgumentError,
        );
      }
      for (final port in [-1, 65536]) {
        await expectLater(
          RpcHttpIsolateServer.start(
            createApp: _createApp,
            port: port,
            workers: 1,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        RpcHttpIsolateServer.start(
          createApp: _createApp,
          port: 0,
          workers: 1,
          startupTimeout: Duration.zero,
        ),
        throwsArgumentError,
      );
    },
  );

  test('shared binding remains opt-in for ordinary apps', () async {
    final first = await _createApp().listen(0, hostname: '127.0.0.1');
    addTearDown(() => first.close(force: true));
    await expectLater(
      _createApp().listen(first.port, hostname: '127.0.0.1', shared: true),
      throwsA(isA<SocketException>()),
    );
  });
}

Stream<Object?> _events(ReceivePort port) =>
    port.cast<Object?>().asBroadcastStream();

RpcHttpApp _createApp() => RpcHttpApp(
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
    RestUnaryRoute(
      method: 'GET',
      path: '/crash',
      handler: (_, _, _) {
        Timer.run(() => throw StateError('uncaught worker failure'));
        return Completer<Object?>().future;
      },
    ),
  ]),
);

Future<RpcHttpApp> _stuckFactory() => Completer<RpcHttpApp>().future;

RpcHttpApp _partiallyFailingApp() {
  if (Isolate.current.debugName == 'dart-orpc-http-1')
    throw StateError('factory failed');
  return _createApp();
}

RpcHttpApp Function() _controlledFactory(SendPort events) =>
    () => RpcHttpApp(
      procedures: RpcProcedureRegistry(const []),
      restRoutes: RestRouteRegistry([
        RestUnaryRoute(
          method: 'GET',
          path: '/wait',
          handler: (context, _, _) async {
            final release = ReceivePort();
            events.send(release.sendPort);
            try {
              await Future.any([release.first, context.cancellation.cancelled]);
              return 'finished';
            } finally {
              release.close();
            }
          },
        ),
      ]),
    );

void Function(RpcHttpApp) _disposer(SendPort events) =>
    (_) => events.send('disposed');
void _failingDispose(RpcHttpApp _) => throw StateError('cleanup failed');

Future<RpcHttpApp> _asyncFailingFactory() {
  Timer.run(() => throw StateError('async startup failed'));
  return Completer<RpcHttpApp>().future;
}

RpcHttpApp Function() _unsendableFactory(ReceivePort resource) => () {
  resource.sendPort.send('created');
  return _createApp();
};

Future<void> Function(RpcHttpApp) _stuckDisposer(SendPort events) => (_) {
  events.send('cleanup entered');
  return Completer<void>().future;
};

RpcHttpApp _exitingFactory() => Isolate.exit();
Future<RpcHttpApp> _vmFailingFactory() {
  Zone.root.run(() => Timer.run(() => throw StateError('VM startup failure')));
  return Completer<RpcHttpApp>().future;
}

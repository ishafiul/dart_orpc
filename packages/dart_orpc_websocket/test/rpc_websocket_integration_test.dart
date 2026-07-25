import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:dart_orpc_websocket/dart_orpc_websocket.dart';
import 'package:test/test.dart';

void main() {
  const environmentKey = RpcContextKey<String>('app.env');

  group('Given WebSocket RPC on an RpcHttpApp', () {
    late RpcHttpServer server;
    late WebSocketRpcTransport transport;
    var streamCancelled = false;

    setUp(() async {
      streamCancelled = false;
      final procedures = RpcProcedureRegistry([
        RpcUnaryProcedure<JsonObject, JsonObject>(
          method: 'math.double',
          metadata: const ProcedureMetadata(
            rpcMethod: 'math.double',
            controllerNamespace: 'math',
            methodName: 'doubleValue',
            outputTypeCode: 'JsonObject',
          ),
          decodeInput: (input) =>
              expectJsonObject(input, context: 'math.double input'),
          encodeOutput: (output) => output,
          handler: (_, input) => {'value': (input['value']! as int) * 2},
        ),
        RpcUnaryProcedure<Null, String>(
          method: 'context.env',
          metadata: const ProcedureMetadata(
            rpcMethod: 'context.env',
            controllerNamespace: 'context',
            methodName: 'env',
            outputTypeCode: 'String',
          ),
          decodeInput: (_) => null,
          encodeOutput: (output) => output,
          handler: (context, _) => context.requireBinding(environmentKey),
        ),
        RpcStreamProcedure<JsonObject, JsonObject>(
          method: 'counter.watch',
          metadata: const ProcedureMetadata(
            rpcMethod: 'counter.watch',
            controllerNamespace: 'counter',
            methodName: 'watch',
            outputTypeCode: 'JsonObject',
            kind: RpcProcedureKind.serverStream,
          ),
          decodeInput: (input) =>
              expectJsonObject(input, context: 'counter.watch input'),
          encodeOutput: (output) => output,
          handler: (_, input) {
            late StreamController<JsonObject> controller;
            Timer? timer;
            controller = StreamController<JsonObject>(
              onListen: () {
                final count = input['count']! as int;
                if (count < 0) {
                  var value = 0;
                  timer = Timer.periodic(
                    const Duration(milliseconds: 1),
                    (_) => controller.add({'value': value++}),
                  );
                  return;
                }
                final start = input['start'] as int? ?? 0;
                for (var value = 0; value < count; value++) {
                  controller.add({'value': start + value});
                }
                unawaited(controller.close());
              },
              onCancel: () {
                timer?.cancel();
                streamCancelled = true;
              },
            );
            return controller.stream;
          },
        ),
      ]);
      final app = RpcHttpApp(
        procedures: procedures,
        bindings: const RpcContextBindings.empty().withValue(
          environmentKey,
          'production',
        ),
        upgradeHandlers: [RpcWebSocketUpgradeHandler(procedures: procedures)],
      );
      server = await app.listen(
        0,
        hostname: InternetAddress.loopbackIPv4.address,
      );
      transport = await WebSocketRpcTransport.connect(
        Uri.parse('ws://${server.address.address}:${server.port}/rpc/ws'),
      );
    });

    tearDown(() async {
      await transport.close();
      await server.close(force: true);
    });

    test(
      'When a unary call is sent then it returns the correlated result',
      () async {
        final result = await transport.send(
          const RpcRequest(method: 'math.double', input: {'value': 21}),
        );

        expect(result, {'value': 42});
        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When app bindings are configured then WebSocket context receives them',
      () async {
        final result = await transport.send(
          const RpcRequest(method: 'context.env'),
        );

        expect(result, 'production');
      },
    );

    test('When a stream is subscribed then it emits ordered events', () async {
      final events = await transport
          .subscribe(
            const RpcRequest(method: 'counter.watch', input: {'count': 3}),
          )
          .toList();

      expect(events, [
        {'value': 0},
        {'value': 1},
        {'value': 2},
      ]);
      expect(transport.pendingCalls, 0);
    });

    test(
      'When unary calls are concurrent then results stay correlated',
      () async {
        final results = await Future.wait([
          for (var value = 0; value < 100; value++)
            transport.send(
              RpcRequest(method: 'math.double', input: {'value': value}),
            ),
        ]);

        expect(results, [
          for (var value = 0; value < 100; value++) {'value': value * 2},
        ]);
        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When 32 streams emit 100 events concurrently then each stream preserves its own ordering',
      () async {
        final results = await Future.wait([
          for (var streamIndex = 0; streamIndex < 32; streamIndex++)
            transport
                .subscribe(
                  RpcRequest(
                    method: 'counter.watch',
                    input: {'count': 100, 'start': streamIndex * 100},
                  ),
                )
                .toList(),
        ]);

        expect(results, [
          for (var streamIndex = 0; streamIndex < 32; streamIndex++)
            [
              for (var value = 0; value < 100; value++)
                {'value': streamIndex * 100 + value},
            ],
        ]);
        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When call kinds do not match then each call fails without closing the connection',
      () async {
        await expectLater(
          transport.send(
            const RpcRequest(method: 'counter.watch', input: {'count': 1}),
          ),
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.badRequest,
            ),
          ),
        );
        await expectLater(
          transport
              .subscribe(
                const RpcRequest(method: 'math.double', input: {'value': 1}),
              )
              .toList(),
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.badRequest,
            ),
          ),
        );

        expect(
          await transport.send(
            const RpcRequest(method: 'math.double', input: {'value': 3}),
          ),
          {'value': 6},
        );
      },
    );

    test(
      'When a stream subscription is cancelled then the source is cancelled',
      () async {
        final firstEvent = Completer<void>();
        final subscription = transport
            .subscribe(
              const RpcRequest(method: 'counter.watch', input: {'count': -1}),
            )
            .listen((_) {
              if (!firstEvent.isCompleted) {
                firstEvent.complete();
              }
            });

        await firstEvent.future.timeout(const Duration(seconds: 2));
        await subscription.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(streamCancelled, isTrue);
        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When a missing method is called then the connection remains usable',
      () async {
        await expectLater(
          transport.send(const RpcRequest(method: 'missing.method')),
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.notFound,
            ),
          ),
        );

        expect(
          await transport.send(
            const RpcRequest(method: 'math.double', input: {'value': 2}),
          ),
          {'value': 4},
        );
      },
    );
  });

  group('Given a WebSocket endpoint requiring its protocol', () {
    test(
      'When a client omits the protocol then the upgrade is rejected',
      () async {
        final procedures = RpcProcedureRegistry(const []);
        final app = RpcHttpApp(
          procedures: procedures,
          upgradeHandlers: [RpcWebSocketUpgradeHandler(procedures: procedures)],
        );
        final server = await app.listen(
          0,
          hostname: InternetAddress.loopbackIPv4.address,
        );

        try {
          await expectLater(
            WebSocket.connect(
              'ws://${server.address.address}:${server.port}/rpc/ws',
            ),
            throwsA(anything),
          );
        } finally {
          await server.close(force: true);
        }
      },
    );
  });

  group('Given raw WebSocket protocol clients', () {
    test(
      'When a malformed text frame is sent then the server closes with protocol error',
      () async {
        final fixture = await _startRawFixture();
        final socket = await _connectRaw(fixture.server);
        final subscription = socket.listen((_) {});
        addTearDown(subscription.cancel);

        socket.add('{');
        await socket.done.timeout(const Duration(seconds: 2));

        expect(socket.closeCode, WebSocketStatus.protocolError);
        await fixture.server.close(force: true);
      },
    );

    test(
      'When a binary frame is sent then the server closes with protocol error',
      () async {
        final fixture = await _startRawFixture();
        final socket = await _connectRaw(fixture.server);
        final subscription = socket.listen((_) {});
        addTearDown(subscription.cancel);

        socket.add(<int>[1, 2, 3]);
        await socket.done.timeout(const Duration(seconds: 2));

        expect(socket.closeCode, WebSocketStatus.protocolError);
        await fixture.server.close(force: true);
      },
    );

    test(
      'When an active id is reused then the original call is cancelled and one conflict error is returned',
      () async {
        final fixture = await _startRawFixture();
        final socket = await _connectRaw(fixture.server);
        final frames = StreamIterator<Object?>(socket);
        const codec = RpcWebSocketFrameCodec();

        socket.add(
          codec.encode(
            const RpcWebSocketCallFrame(
              id: 'same',
              kind: RpcWebSocketCallKind.stream,
              method: 'events.forever',
            ),
          ),
        );
        expect(await frames.moveNext(), isTrue);
        expect(codec.decode(frames.current), isA<RpcWebSocketNextFrame>());

        socket.add(
          codec.encode(
            const RpcWebSocketCallFrame(
              id: 'same',
              kind: RpcWebSocketCallKind.unary,
              method: 'echo.value',
              input: {'value': 1},
            ),
          ),
        );
        expect(await frames.moveNext(), isTrue);
        final conflict = codec.decode(frames.current);

        expect(conflict, isA<RpcWebSocketErrorFrame>());
        expect(
          (conflict as RpcWebSocketErrorFrame).error.code,
          RpcErrorCode.conflict.wireName,
        );
        await fixture.cancelled.future.timeout(const Duration(seconds: 2));

        socket.add(
          codec.encode(
            const RpcWebSocketCallFrame(
              id: 'next',
              kind: RpcWebSocketCallKind.unary,
              method: 'echo.value',
              input: {'value': 7},
            ),
          ),
        );
        expect(await frames.moveNext(), isTrue);
        expect(codec.decode(frames.current).toJson(), {
          'type': 'result',
          'id': 'next',
          'data': {'value': 7},
        });

        await frames.cancel();
        await socket.close();
        await fixture.server.close(force: true);
      },
    );

    test(
      'When the server shuts down then active sockets close with going away and streams are cancelled',
      () async {
        final fixture = await _startRawFixture();
        final socket = await _connectRaw(fixture.server);
        const codec = RpcWebSocketFrameCodec();
        final frames = StreamIterator<Object?>(socket);
        addTearDown(frames.cancel);

        socket.add(
          codec.encode(
            const RpcWebSocketCallFrame(
              id: 'stream',
              kind: RpcWebSocketCallKind.stream,
              method: 'events.forever',
            ),
          ),
        );
        expect(
          await frames.moveNext().timeout(const Duration(seconds: 2)),
          isTrue,
        );

        await fixture.server.close(gracePeriod: Duration.zero);
        expect(
          await frames.moveNext().timeout(const Duration(seconds: 2)),
          isFalse,
        );
        await socket.done;

        expect(socket.closeCode, WebSocketStatus.goingAway);
        await fixture.cancelled.future.timeout(const Duration(seconds: 2));
      },
    );

    test(
      'When a connection finishes inside the grace period then shutdown drains without forcing it',
      () async {
        final fixture = await _startRawFixture();
        final socket = await _connectRaw(fixture.server);
        final subscription = socket.listen((_) {});
        addTearDown(subscription.cancel);

        final closing = fixture.server.close(
          gracePeriod: const Duration(seconds: 1),
        );
        await socket.close();
        await closing.timeout(const Duration(seconds: 2));

        expect(socket.closeCode, isNot(WebSocketStatus.goingAway));
      },
    );

    test(
      'When draining begins then existing sockets reject new calls',
      () async {
        const codec = RpcWebSocketFrameCodec();
        final fixture = await _startRawFixture();
        final socket = await _connectRaw(fixture.server);
        final frames = StreamIterator<Object?>(socket);
        addTearDown(frames.cancel);

        final closing = fixture.upgradeHandler.close(
          gracePeriod: const Duration(milliseconds: 100),
        );
        socket.add(
          codec.encode(
            const RpcWebSocketCallFrame(
              id: 'after-drain',
              kind: RpcWebSocketCallKind.unary,
              method: 'echo.value',
              input: {'value': 1},
            ),
          ),
        );

        expect(
          await frames.moveNext().timeout(const Duration(seconds: 2)),
          isTrue,
        );
        final error = codec.decode(frames.current) as RpcWebSocketErrorFrame;
        expect(error.id, 'after-drain');
        expect(error.error.code, 'CANCELLED');
        await closing.timeout(const Duration(seconds: 2));
      },
    );

    test(
      'When a custom path is normalized then upgrades match with or without edge slashes',
      () async {
        final fixture = await _startRawFixture(
          options: const RpcWebSocketServerOptions(path: 'custom/ws/'),
        );
        final socket = await WebSocket.connect(
          'ws://${fixture.server.address.address}:${fixture.server.port}/custom/ws',
          protocols: const [rpcWebSocketSubprotocol],
        );
        addTearDown(socket.close);

        expect(socket.protocol, rpcWebSocketSubprotocol);
      },
    );

    test(
      'When the connection limit is reached then another upgrade is rejected',
      () async {
        final fixture = await _startRawFixture(
          options: const RpcWebSocketServerOptions(maxConnections: 1),
        );
        final first = await _connectRaw(fixture.server);

        await expectLater(_connectRaw(fixture.server), throwsA(anything));

        await first.close();
        await fixture.server.close(force: true);
      },
    );

    test(
      'When the active call limit is reached then only the additional call is rejected',
      () async {
        final fixture = await _startRawFixture(
          options: const RpcWebSocketServerOptions(
            maxActiveCallsPerConnection: 1,
          ),
        );
        final transport = await WebSocketRpcTransport.connect(
          Uri.parse(
            'ws://${fixture.server.address.address}:${fixture.server.port}/rpc/ws',
          ),
        );
        addTearDown(transport.close);
        final firstEvent = Completer<void>();
        final subscription = transport
            .subscribe(const RpcRequest(method: 'events.forever'))
            .listen((_) => firstEvent.complete());
        addTearDown(subscription.cancel);
        await firstEvent.future.timeout(const Duration(seconds: 2));

        await expectLater(
          transport.send(
            const RpcRequest(method: 'echo.value', input: {'value': 1}),
          ),
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.resourceExhausted,
            ),
          ),
        );

        await subscription.cancel();
        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When a stream event exceeds its call buffer then that call fails with resource exhausted',
      () async {
        final fixture = await _startRawFixture(
          options: const RpcWebSocketServerOptions(
            maxBufferedBytesPerCall: 100,
          ),
        );
        final transport = await WebSocketRpcTransport.connect(
          Uri.parse(
            'ws://${fixture.server.address.address}:${fixture.server.port}/rpc/ws',
          ),
        );
        addTearDown(transport.close);

        await expectLater(
          transport
              .subscribe(const RpcRequest(method: 'events.forever'))
              .toList(),
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.resourceExhausted,
            ),
          ),
        );

        expect(transport.pendingCalls, 0);
        expect(
          await transport.send(
            const RpcRequest(method: 'echo.value', input: {'value': 2}),
          ),
          {'value': 2},
        );
      },
    );

    test(
      'When an upgrade authorizer rejects then its RPC code is preserved in the HTTP response',
      () async {
        final fixture = await _startRawFixture(
          options: RpcWebSocketServerOptions(
            authorize: (_) => throw RpcException.forbidden('denied'),
          ),
        );
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse(
            'http://${fixture.server.address.address}:${fixture.server.port}/rpc/ws',
          ),
        );
        request.headers
          ..set(HttpHeaders.connectionHeader, 'Upgrade')
          ..set(HttpHeaders.upgradeHeader, 'websocket')
          ..set('sec-websocket-version', '13')
          ..set('sec-websocket-key', base64.encode(List<int>.filled(16, 1)))
          ..set('sec-websocket-protocol', rpcWebSocketSubprotocol);

        final response = await request.close();
        final body = await utf8.decodeStream(response);

        expect(response.statusCode, HttpStatus.forbidden);
        expect(
          jsonDecode(body),
          RpcException.forbidden('denied').toResponse().toJson(),
        );
        client.close(force: true);
        await fixture.server.close(force: true);
      },
    );
  });
}

Future<_RawFixture> _startRawFixture({
  RpcWebSocketServerOptions options = const RpcWebSocketServerOptions(),
}) async {
  final cancelled = Completer<void>();
  final procedures = RpcProcedureRegistry([
    RpcUnaryProcedure<JsonObject, JsonObject>(
      method: 'echo.value',
      metadata: const ProcedureMetadata(
        rpcMethod: 'echo.value',
        controllerNamespace: 'echo',
        methodName: 'value',
        outputTypeCode: 'JsonObject',
      ),
      decodeInput: (input) => expectJsonObject(input, context: 'echo input'),
      encodeOutput: (output) => output,
      handler: (_, input) => input,
    ),
    RpcStreamProcedure<Null, JsonObject>(
      method: 'events.forever',
      metadata: const ProcedureMetadata(
        rpcMethod: 'events.forever',
        controllerNamespace: 'events',
        methodName: 'forever',
        outputTypeCode: 'JsonObject',
        kind: RpcProcedureKind.serverStream,
      ),
      decodeInput: (_) => null,
      encodeOutput: (output) => output,
      handler: (_, _) {
        late StreamController<JsonObject> controller;
        controller = StreamController<JsonObject>(
          onListen: () => controller.add({'value': 'x' * 256}),
          onCancel: () {
            if (!cancelled.isCompleted) {
              cancelled.complete();
            }
          },
        );
        return controller.stream;
      },
    ),
  ]);
  final upgradeHandler = RpcWebSocketUpgradeHandler(
    procedures: procedures,
    options: options,
  );
  final app = RpcHttpApp(
    procedures: procedures,
    upgradeHandlers: [upgradeHandler],
  );
  final server = await app.listen(
    0,
    hostname: InternetAddress.loopbackIPv4.address,
  );
  addTearDown(() => server.close(force: true));
  return _RawFixture(server, cancelled, upgradeHandler);
}

Future<WebSocket> _connectRaw(RpcHttpServer server) async {
  final socket = await WebSocket.connect(
    'ws://${server.address.address}:${server.port}/rpc/ws',
    protocols: const [rpcWebSocketSubprotocol],
  );
  addTearDown(socket.close);
  return socket;
}

final class _RawFixture {
  const _RawFixture(this.server, this.cancelled, this.upgradeHandler);

  final RpcHttpServer server;
  final Completer<void> cancelled;
  final RpcWebSocketUpgradeHandler upgradeHandler;
}

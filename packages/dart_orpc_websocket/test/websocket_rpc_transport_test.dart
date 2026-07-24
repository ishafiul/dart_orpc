import 'dart:async';
import 'dart:io';

import 'package:dart_orpc_client/dart_orpc_client.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_websocket/dart_orpc_websocket.dart';
import 'package:test/test.dart';

void main() {
  group('Given a VM WebSocket RPC client transport', () {
    test(
      'When the server returns an unknown RPC error code then the call fails as a transport contract error',
      () async {
        const codec = RpcWebSocketFrameCodec();
        final endpoint = await _serveWebSocket((socket) {
          socket.listen((message) {
            final call = codec.decode(message) as RpcWebSocketCallFrame;
            socket.add(
              codec.encode(
                RpcWebSocketErrorFrame(
                  id: call.id,
                  error: const RpcErrorBody(
                    code: 'FUTURE_ERROR',
                    message: 'unknown',
                  ),
                ),
              ),
            );
          });
        });
        final transport = await WebSocketRpcTransport.connect(endpoint);
        addTearDown(transport.close);

        await expectLater(
          transport.send(const RpcRequest(method: 'test.call')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains('unknown error code'),
            ),
          ),
        );
        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When the server sends malformed JSON then every pending call fails and the transport closes',
      () async {
        final endpoint = await _serveWebSocket((socket) {
          socket.listen((_) => socket.add('{'));
        });
        final transport = await WebSocketRpcTransport.connect(endpoint);
        addTearDown(transport.close);

        await expectLater(
          transport.send(const RpcRequest(method: 'test.call')),
          throwsA(isA<RpcClientException>()),
        );

        expect(transport.pendingCalls, 0);
        await expectLater(
          transport.send(const RpcRequest(method: 'test.again')),
          throwsA(isA<RpcClientException>()),
        );
      },
    );

    test(
      'When the server sends a client-only frame then the protocol fails every pending call',
      () async {
        const codec = RpcWebSocketFrameCodec();
        final endpoint = await _serveWebSocket((socket) {
          socket.listen((message) {
            final incoming = codec.decode(message) as RpcWebSocketCallFrame;
            socket.add(
              codec.encode(
                RpcWebSocketCallFrame(
                  id: incoming.id,
                  kind: RpcWebSocketCallKind.unary,
                  method: 'invalid.server.call',
                ),
              ),
            );
          });
        });
        final transport = await WebSocketRpcTransport.connect(endpoint);
        addTearDown(transport.close);

        await expectLater(
          transport.send(const RpcRequest(method: 'test.call')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains('client-only frame'),
            ),
          ),
        );

        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When a stream receives a known RPC error then it preserves the server failure',
      () async {
        const codec = RpcWebSocketFrameCodec();
        final endpoint = await _serveWebSocket((socket) {
          socket.listen((message) {
            final incoming = codec.decode(message) as RpcWebSocketCallFrame;
            socket.add(
              codec.encode(
                RpcWebSocketErrorFrame(
                  id: incoming.id,
                  error: const RpcErrorBody(
                    code: 'FORBIDDEN',
                    message: 'Access denied.',
                  ),
                ),
              ),
            );
          });
        });
        final transport = await WebSocketRpcTransport.connect(endpoint);
        addTearDown(transport.close);

        await expectLater(
          transport.subscribe(const RpcRequest(method: 'events.watch')),
          emitsError(
            isA<RpcException>()
                .having((error) => error.code, 'code', RpcErrorCode.forbidden)
                .having((error) => error.message, 'message', 'Access denied.'),
          ),
        );

        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When a stream receives a unary result then the protocol closes safely',
      () async {
        const codec = RpcWebSocketFrameCodec();
        final endpoint = await _serveWebSocket((socket) {
          socket.listen((message) {
            final incoming = codec.decode(message) as RpcWebSocketCallFrame;
            socket.add(
              codec.encode(
                RpcWebSocketResultFrame(id: incoming.id, data: 'invalid'),
              ),
            );
          });
        });
        final transport = await WebSocketRpcTransport.connect(endpoint);
        addTearDown(transport.close);

        await expectLater(
          transport.subscribe(const RpcRequest(method: 'events.watch')),
          emitsError(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains('Unexpected result frame'),
            ),
          ),
        );

        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When the socket disconnects then a pending call fails exactly once and is released',
      () async {
        final endpoint = await _serveWebSocket((socket) {
          socket.listen((_) => socket.close());
        });
        final transport = await WebSocketRpcTransport.connect(endpoint);
        addTearDown(transport.close);

        var failures = 0;
        try {
          await transport.send(const RpcRequest(method: 'test.call'));
          fail('The pending call should fail.');
        } on RpcClientException {
          failures++;
        }

        expect(failures, 1);
        expect(transport.pendingCalls, 0);
      },
    );

    test(
      'When a stream subscription is cancelled then the client sends one cancel frame',
      () async {
        const codec = RpcWebSocketFrameCodec();
        final cancelReceived = Completer<String>();
        final endpoint = await _serveWebSocket((socket) {
          socket.listen((message) {
            switch (codec.decode(message)) {
              case RpcWebSocketCallFrame(:final id):
                socket.add(
                  codec.encode(
                    RpcWebSocketNextFrame(id: id, data: const {'value': 1}),
                  ),
                );
              case RpcWebSocketCancelFrame(:final id):
                if (!cancelReceived.isCompleted) {
                  cancelReceived.complete(id);
                }
              default:
                fail('Unexpected client frame.');
            }
          });
        });
        final transport = await WebSocketRpcTransport.connect(endpoint);
        addTearDown(transport.close);
        final firstEvent = Completer<void>();
        final subscription = transport
            .subscribe(const RpcRequest(method: 'events.watch'))
            .listen((_) => firstEvent.complete());

        await firstEvent.future.timeout(const Duration(seconds: 2));
        await subscription.cancel();

        expect(
          await cancelReceived.future.timeout(const Duration(seconds: 2)),
          '1',
        );
        expect(transport.pendingCalls, 0);
      },
    );

    test('When close is called repeatedly then it is idempotent', () async {
      final endpoint = await _serveWebSocket((socket) {
        socket.listen((_) {});
      });
      final transport = await WebSocketRpcTransport.connect(endpoint);

      await Future.wait([transport.close(), transport.close()]);

      expect(transport.pendingCalls, 0);
      await expectLater(
        transport.send(const RpcRequest(method: 'test.call')),
        throwsA(isA<RpcClientException>()),
      );
    });

    test(
      'When the server does not negotiate dart-orpc.v1 then connection fails',
      () async {
        final endpoint = await _serveWebSocket(
          (socket) => socket.close(),
          negotiateProtocol: false,
        );

        await expectLater(
          WebSocketRpcTransport.connect(endpoint),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains('did not negotiate'),
            ),
          ),
        );
      },
    );

    test('When the endpoint cannot connect then it fails clearly', () async {
      final unavailable = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = unavailable.port;
      await unavailable.close();

      await expectLater(
        WebSocketRpcTransport.connect(
          Uri.parse(
            'ws://${InternetAddress.loopbackIPv4.address}:$port/rpc/ws',
          ),
        ),
        throwsA(
          isA<RpcClientException>().having(
            (error) => error.message,
            'message',
            contains('Failed to connect'),
          ),
        ),
      );
    });
  });
}

Future<Uri> _serveWebSocket(
  void Function(WebSocket socket) onSocket, {
  bool negotiateProtocol = true,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    final socket = await WebSocketTransformer.upgrade(
      request,
      protocolSelector: negotiateProtocol
          ? (protocols) => protocols.contains(rpcWebSocketSubprotocol)
                ? rpcWebSocketSubprotocol
                : null
          : null,
    );
    onSocket(socket);
  });
  return Uri.parse('ws://${server.address.address}:${server.port}/rpc/ws');
}

import 'dart:async';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_websocket/dart_orpc_websocket.dart';
import 'package:test/test.dart';

void main() {
  test('Given a dart:io upgrade request When offered to the handler Then it is neither taken nor upgraded', () async {
    final handler = RpcWebSocketUpgradeHandler(
      procedures: RpcProcedureRegistry(const []),
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final offered = Completer<bool>();
    final handled = Completer<Object?>();
    server.listen((request) async {
      offered.complete(handler.canHandle(request));
      try {
        await handler.handle(
          request,
          RpcContext(headers: const {}),
          (_, _, {rpcMethod, callId}) {},
        );
        handled.complete(null);
      } on Object catch (error) {
        handled.complete(error);
      }
      request.response.statusCode = HttpStatus.notFound;
      unawaited(request.response.close());
    });

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.get('127.0.0.1', server.port, '/rpc/ws');
    request.headers
      ..set(HttpHeaders.connectionHeader, 'Upgrade')
      ..set(HttpHeaders.upgradeHeader, 'websocket')
      ..set('sec-websocket-version', '13')
      ..set('sec-websocket-key', 'dGhlIHNhbXBsZSBub25jZQ==');
    await (await request.close()).drain<void>();

    expect(await offered.future, isFalse);
    expect(await handled.future, isA<ArgumentError>());
  });
}

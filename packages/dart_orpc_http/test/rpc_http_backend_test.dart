import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:rust_http/rust_http.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given an RPC app When it listens Then rust_http serves its requests',
    () async {
      final seen = _RecordingUpgradeHandler();
      final server = await RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        upgradeHandlers: [seen],
      ).listen(0, hostname: '127.0.0.1');
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));

      final response = await (await client.get(
        '127.0.0.1',
        server.port,
        '/rpc',
      )).close();
      await response.drain<void>();

      expect(seen.requests, isNotEmpty);
      expect(seen.requests, everyElement(isA<RustHttpRequest>()));
    },
  );
}

/// Records each request the app offers it, and handles none.
final class _RecordingUpgradeHandler implements RpcHttpUpgradeHandler {
  final List<HttpRequest> requests = [];

  @override
  bool canHandle(HttpRequest request) {
    requests.add(request);
    return false;
  }

  @override
  Future<void> handle(
    HttpRequest request,
    RpcContext context,
    RpcUpgradeErrorReporter reportError,
  ) async {}

  @override
  Future<void> close({required Duration gracePeriod}) async {}
}

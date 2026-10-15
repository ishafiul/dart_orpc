import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  test('server shutdown disposes app providers exactly once', () async {
    var closeCount = 0;
    final app = RpcHttpApp(
      procedures: RpcProcedureRegistry(const []),
      onClose: () => closeCount++,
    );
    final server = await app.listen(
      0,
      hostname: InternetAddress.loopbackIPv4.address,
    );

    await server.close(gracePeriod: Duration.zero);
    await app.close();

    expect(closeCount, 1);
    await expectLater(app.listen(0), throwsStateError);
  });

  test('closing an app before listening disposes providers', () async {
    var closeCount = 0;
    final app = RpcHttpApp(
      procedures: RpcProcedureRegistry(const []),
      onClose: () => closeCount++,
    );

    await app.close();
    await app.close();

    expect(closeCount, 1);
    await expectLater(app.listen(0), throwsStateError);
  });

  test(
    'closing while listen is binding waits for the pending listener',
    () async {
      var closeCount = 0;
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        onClose: () => closeCount++,
      );
      final listening = app.listen(
        0,
        hostname: InternetAddress.loopbackIPv4.address,
      );

      final closing = app.close();
      await expectLater(listening, throwsStateError);
      await closing;

      expect(closeCount, 1);
    },
  );
}

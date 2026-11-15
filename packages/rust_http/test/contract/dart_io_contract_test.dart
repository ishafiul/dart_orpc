import 'dart:io';

import 'http_server_contract.dart';

/// The reference: dart:io must pass the whole contract.
void main() {
  runHttpServerContract(
    name: 'dart:io HttpServer',
    bind: ({port = 0, shared = false}) =>
        HttpServer.bind('127.0.0.1', port, shared: shared),
    upgradeWebSocket: WebSocketTransformer.upgrade,
  );
}

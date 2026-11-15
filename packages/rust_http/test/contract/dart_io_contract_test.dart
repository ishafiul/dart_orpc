import 'dart:io';

import 'http_server_contract.dart';

/// The reference: dart:io must pass the whole contract.
void main() {
  runHttpServerContract(
    name: 'dart:io HttpServer',
    bind: () => HttpServer.bind('127.0.0.1', 0),
    upgradeWebSocket: WebSocketTransformer.upgrade,
  );
}

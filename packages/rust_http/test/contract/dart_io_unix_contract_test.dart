@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'unix_socket_contract.dart';

/// The reference: dart:io must pass the whole contract.
void main() {
  runUnixSocketContract(
    name: 'dart:io HttpServer',
    bind: (address, {shared = false}) =>
        HttpServer.bind(address, 0, shared: shared),
    upgradeWebSocket: WebSocketTransformer.upgrade,
  );
}

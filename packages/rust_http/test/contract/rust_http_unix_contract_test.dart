@TestOn('mac-os || linux')
library;

import 'package:rust_http/rust_http.dart';
import 'package:test/test.dart';

import 'unix_socket_contract.dart';

void main() {
  runUnixSocketContract(
    name: 'RustHttpServer',
    bind: (address, {shared = false}) =>
        RustHttpServer.bind(0, address: address, shared: shared),
    upgradeWebSocket: RustWebSocket.upgrade,
  );
}

import 'package:rust_http/rust_http.dart';

import 'http_server_contract.dart';

void main() {
  runHttpServerContract(
    name: 'RustHttpServer',
    bind: ({port = 0, shared = false}) =>
        RustHttpServer.bind(port, address: '127.0.0.1', shared: shared),
    upgradeWebSocket: RustWebSocket.upgrade,
  );
}

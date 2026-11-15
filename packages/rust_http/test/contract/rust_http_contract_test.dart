import 'package:rust_http/rust_http.dart';

import 'http_server_contract.dart';

void main() {
  runHttpServerContract(
    name: 'RustHttpServer',
    bind: () => RustHttpServer.bind(0, address: '127.0.0.1'),
    upgradeWebSocket: RustWebSocket.upgrade,
  );
}

// Serves "Hello World" on the given port with RustHttpServer, or with
// dart:io HttpServer when the second argument is `io`.
import 'dart:async';
import 'dart:io';

import 'package:rust_http/rust_http.dart';

Future<void> main(List<String> arguments) async {
  final port = arguments.isEmpty ? 8080 : int.parse(arguments.first);
  final useDartIo = arguments.length > 1 && arguments[1] == 'io';
  final HttpServer server = useDartIo
      ? await HttpServer.bind(InternetAddress.loopbackIPv4, port)
      : await RustHttpServer.bind(port, address: '127.0.0.1');
  stdout.writeln('${useDartIo ? 'dart:io' : 'rust_http'} on ${server.port}');
  server.listen((request) {
    request.response.write('Hello World');
    unawaited(request.response.close());
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc/dart_orpc.dart';
import 'package:dart_orpc_benchmark/benchmark_app.orpc.dart';

const _message = 'Hello, World!';

Future<void> main() async {
  final app = const BenchmarkModule().buildRpcApp(
    middleware: [_microBenchmarkMiddleware],
  );

  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final server = await app.listen(port);
  stdout.writeln('READY dart_orpc ${server.port}');
}

RpcHttpHandler _microBenchmarkMiddleware(RpcHttpHandler next) {
  return (request) {
    if (request.method == 'GET') {
      if (request.path == '/plaintext') {
        return Future.value(
          const RpcHttpResponse(
            statusCode: HttpStatus.ok,
            headers: {'content-type': 'text/plain; charset=utf-8'},
            body: _message,
          ),
        );
      }
      if (request.path == '/json') {
        return Future.value(
          RpcHttpResponse(
            statusCode: HttpStatus.ok,
            headers: const {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode(const {'message': _message}),
          ),
        );
      }
    }
    if (request.method == 'POST' && request.path == '/echo') {
      return Future.value(
        RpcHttpResponse(
          statusCode: HttpStatus.ok,
          headers: const {'content-type': 'application/json; charset=utf-8'},
          body: jsonEncode(jsonDecode(request.body)),
        ),
      );
    }
    return next(request);
  };
}

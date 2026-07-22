import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';

const _message = 'Hello, World!';

Future<void> main() async {
  final app = RpcHttpApp(
    procedures: RpcProcedureRegistry([_echoProcedure()]),
    restRoutes: RestRouteRegistry([
      RestRoute(
        method: 'GET',
        path: '/json',
        handler: (_, _, _) => const {'message': _message},
      ),
      RestRoute(
        method: 'POST',
        path: '/echo',
        handler: (_, request, _) => jsonDecode(request.body),
      ),
    ]),
    middleware: [_plaintextMiddleware],
  );

  final port = int.parse(Platform.environment['PORT'] ?? '8081');
  final server = await app.listen(port);
  stdout.writeln('READY dart_orpc ${server.port}');
}

RpcProcedure<Map<String, Object?>, Map<String, Object?>> _echoProcedure() {
  const metadata = ProcedureMetadata(
    rpcMethod: 'benchmark.echo',
    controllerNamespace: 'benchmark',
    methodName: 'echo',
    inputTypeCode: 'Map<String, Object?>',
    outputTypeCode: 'Map<String, Object?>',
  );

  return RpcProcedure(
    method: metadata.rpcMethod,
    metadata: metadata,
    decodeInput: _decodeMap,
    encodeOutput: (output) => output,
    handler: (_, input) => input,
  );
}

Map<String, Object?> _decodeMap(Object? input) {
  if (input is! Map) {
    throw RpcException.badRequest('Input must be a JSON object.');
  }

  return input.map((key, value) => MapEntry(key.toString(), value));
}

RpcHttpHandler _plaintextMiddleware(RpcHttpHandler next) {
  return (request) {
    if (request.method == 'GET' && request.path == '/plaintext') {
      return Future.value(
        const RpcHttpResponse(
          statusCode: HttpStatus.ok,
          headers: {'content-type': 'text/plain; charset=utf-8'},
          body: _message,
        ),
      );
    }
    return next(request);
  };
}

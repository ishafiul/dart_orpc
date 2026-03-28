import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_http_handler.dart';

final class RpcHttpApp {
  RpcHttpApp({
    required RpcProcedureRegistry procedures,
    RestRouteRegistry? restRoutes,
  }) : procedures = procedures,
       restRoutes = restRoutes ?? RestRouteRegistry(const []),
       handler = createRpcHttpHandler(
         procedures: procedures,
         restRoutes: restRoutes,
       );

  final RpcProcedureRegistry procedures;
  final RestRouteRegistry restRoutes;
  final RpcHttpHandler handler;

  Future<HttpServer> listen(int port, {String hostname = '0.0.0.0'}) async {
    final server = await HttpServer.bind(hostname, port);
    unawaited(_serve(server));
    return server;
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final response = await handler(
        RpcHttpRequest(
          method: request.method,
          path: request.uri.path.isEmpty ? '/' : request.uri.path,
          headers: _flattenHeaders(request.headers),
          queryParameters: request.uri.queryParameters,
          body: await utf8.decoder.bind(request).join(),
        ),
      );

      request.response.statusCode = response.statusCode;
      response.headers.forEach(request.response.headers.set);
      request.response.write(response.body);
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.set(
        'content-type',
        'application/json; charset=utf-8',
      );
      request.response.write(
        jsonEncode(RpcException.internalError().toResponse().toJson()),
      );
      await request.response.close();
    }
  }

  Map<String, String> _flattenHeaders(HttpHeaders headers) {
    final flattened = <String, String>{};
    headers.forEach((name, values) {
      if (values.isNotEmpty) {
        flattened[name] = values.join(',');
      }
    });

    return Map<String, String>.unmodifiable(flattened);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_http_handler.dart';

const int _defaultMaxRequestBodyBytes = 1024 * 1024;

final class RpcHttpApp {
  RpcHttpApp({
    required RpcProcedureRegistry procedures,
    RestRouteRegistry? restRoutes,
    this.openApiDocument,
    this.openApiPath = '/openapi.json',
    this.docsHtml,
    this.docsPath = '/docs',
    this.docsBasicAuth,
    this.staticAssets,
    this.health,
    this.metrics,
    this.maxRequestBodyBytes = _defaultMaxRequestBodyBytes,
    Iterable<RpcHttpMiddleware> middleware = const [],
  }) : assert(
         maxRequestBodyBytes == null || maxRequestBodyBytes > 0,
         'maxRequestBodyBytes must be greater than zero when set.',
       ),
       procedures = procedures,
        restRoutes = restRoutes ?? RestRouteRegistry(const []),
        middleware = List<RpcHttpMiddleware>.unmodifiable(middleware),
        handler = createRpcHttpHandler(
         procedures: procedures,
         restRoutes: restRoutes,
         openApiDocument: openApiDocument,
         openApiPath: openApiPath,
         docsHtml: docsHtml,
         docsPath: docsPath,
         docsBasicAuth: docsBasicAuth,
         staticAssets: staticAssets,
         health: health,
         metrics: metrics,
         middleware: middleware,
       );

  final RpcProcedureRegistry procedures;
  final RestRouteRegistry restRoutes;
  final JsonObject? openApiDocument;
  final String openApiPath;
  final String? docsHtml;
  final String docsPath;
  final RpcHttpBasicAuth? docsBasicAuth;
  final RpcHttpStaticOptions? staticAssets;
  final RpcHttpHealthOptions? health;
  final RpcHttpMetricsOptions? metrics;
  final int? maxRequestBodyBytes;
  final List<RpcHttpMiddleware> middleware;
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
      final requestBody = await _readRequestBody(request);
      final response = await handler(
        RpcHttpRequest(
          method: request.method,
          path: request.uri.path.isEmpty ? '/' : request.uri.path,
          headers: _flattenHeaders(request.headers),
          queryParameters: request.uri.queryParameters,
          body: requestBody,
        ),
      );

      request.response.statusCode = response.statusCode;
      response.headers.forEach(request.response.headers.set);
      final body = response.body;
      if (body is List<int>) {
        request.response.add(body);
      } else if (body != null) {
        request.response.write(body);
      }
      await request.response.close();
    } on _PayloadTooLargeException {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      request.response.headers.set(
        'content-type',
        'application/json; charset=utf-8',
      );
      request.response.write(
        jsonEncode({
          'error': {
            'code': 'PAYLOAD_TOO_LARGE',
            'message':
                'Request body exceeds the maximum allowed size of '
                '$maxRequestBodyBytes bytes.',
          },
        }),
      );
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

  Future<String> _readRequestBody(HttpRequest request) async {
    final limit = maxRequestBodyBytes;

    final announcedLength = request.contentLength;
    if (limit != null && announcedLength > limit) {
      throw const _PayloadTooLargeException();
    }

    final bytes = <int>[];
    var receivedBytes = 0;

    await for (final chunk in request) {
      receivedBytes += chunk.length;
      if (limit != null && receivedBytes > limit) {
        throw const _PayloadTooLargeException();
      }
      bytes.addAll(chunk);
    }

    return utf8.decode(bytes);
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

final class _PayloadTooLargeException implements Exception {
  const _PayloadTooLargeException();
}

import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';

Future<void> main() async {
  final app = const AppModule().buildRpcApp(
    openApi: const OpenApiDocumentOptions(
      title: 'Basic App API',
      description: 'Example todo API built with dart_orpc.',
    ),
    docs: const RpcHttpDocsOptions(
      title: 'Basic App Docs',
      basicAuth: RpcHttpBasicAuth(
        username: 'admin',
        password: 'secret',
        realm: 'Basic App Docs',
      ),
    ),
    middleware: [
      createCorsMiddleware(),
      _requestLoggingMiddleware,
    ],
    staticAssets: const RpcHttpStaticOptions(
      directory: 'public',
    ),
    health: const RpcHttpHealthOptions(),
    metrics: const RpcHttpMetricsOptions(),
  );
  final server = await app.listen(3000);
  final baseUrl = 'http://127.0.0.1:${server.port}';
  print('RPC server listening on $baseUrl/rpc');
}

RpcHttpHandler _requestLoggingMiddleware(RpcHttpHandler next) {
  return (request) async {
    final startedAt = DateTime.now();
    try {
      final response = await next(request);
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      print(
        '[${request.method}] ${request.path} -> ${response.statusCode} (${elapsedMs}ms)',
      );
      return response;
    } catch (error) {
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      print('[${request.method}] ${request.path} -> ERROR (${elapsedMs}ms)');
      rethrow;
    }
  };
}

import 'package:basic_app/basic_app.dart';
import 'package:basic_app/environment/app_env.dart';
import 'package:dart_orpc/dart_orpc.dart';

Future<void> main() async {
  final env = AppEnv.load();
  final app = const AppModule().buildRpcApp(
    openApi: const OpenApiDocumentOptions(
      title: 'Basic App API',
      description: 'Example todo API built with dart_orpc.',
    ),
    docs: RpcHttpDocsOptions(
      title: 'Basic App Docs',
      // basicAuth: RpcHttpBasicAuth(
      //   username: env.docsUsername,
      //   password: env.docsPassword,
      //   realm: env.docsRealm,
      // ),
    ),
    middleware: [createCorsMiddleware(), _requestLoggingMiddleware],
    staticAssets: const RpcHttpStaticOptions(directory: 'public'),
    health: const RpcHttpHealthOptions(),
    metrics: const RpcHttpMetricsOptions(),
    webSocket: const RpcWebSocketServerOptions(),
    bindings: const RpcContextBindings.empty().withValue(appEnvKey, env),
  );
  final server = await app.listen(env.port);
  final baseUrl = 'http://127.0.0.1:${server.port}';
  print('RPC server listening on $baseUrl/rpc');
  print('WebSocket RPC listening on ws://127.0.0.1:${server.port}/rpc/ws');
  print('Todo SSE stream available at $baseUrl/todos/events');
  print('Todo live SSE stream available at $baseUrl/todos/live-events');
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

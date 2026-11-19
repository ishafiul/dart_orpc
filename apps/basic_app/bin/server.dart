import 'dart:io';

import 'package:basic_app/basic_app.dart';
import 'package:basic_app/environment/app_env.dart';
import 'package:dart_orpc/dart_orpc.dart';

const _docsTitle = 'Basic App Docs';
const _staticAssetsFolder = 'public';

String _baseUrl(int port) => 'http://127.0.0.1:$port';

String _startupBanner(int port) =>
    'RPC server listening on ${_baseUrl(port)}/rpc\n'
    'WebSocket RPC listening on ws://127.0.0.1:$port/rpc/ws\n'
    'Todo SSE stream available at ${_baseUrl(port)}/todos/events\n'
    'Todo live SSE stream available at ${_baseUrl(port)}/todos/live-events';

String _requestLine(RpcHttpRequest request, Object outcome, Duration elapsed) =>
    '[${request.method}] ${request.path} -> $outcome '
    '(${elapsed.inMilliseconds}ms)';

const _failedOutcome = 'ERROR';

Future<void> main() async {
  final env = AppEnv.load();
  final app = const AppModule().buildRpcApp(
    openApi: basicAppOpenApiOptions,
    docs: const RpcHttpDocsOptions(title: _docsTitle),
    middleware: [createCorsMiddleware(), _requestLoggingMiddleware],
    staticAssets: const RpcHttpStaticOptions(directory: _staticAssetsFolder),
    health: const RpcHttpHealthOptions(),
    metrics: const RpcHttpMetricsOptions(),
    webSocket: const RpcWebSocketServerOptions(),
    bindings: const RpcContextBindings.empty().withValue(appEnvKey, env),
  );
  final server = await app.listen(env.port);
  stdout.writeln(_startupBanner(server.port));
}

RpcHttpHandler _requestLoggingMiddleware(RpcHttpHandler next) {
  return (request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await next(request);
      stdout.writeln(
        _requestLine(request, response.statusCode, stopwatch.elapsed),
      );
      return response;
    } on Object {
      stdout.writeln(_requestLine(request, _failedOutcome, stopwatch.elapsed));
      rethrow;
    }
  };
}

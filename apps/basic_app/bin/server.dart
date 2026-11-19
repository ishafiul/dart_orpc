import 'package:basic_app/basic_app.dart';
import 'package:basic_app/environment/app_env.dart';
import 'package:dart_orpc/dart_orpc.dart';

const _serviceName = 'basic_app';
const _docsTitle = 'Basic App Docs';
const _staticAssetsFolder = 'public';

RpcLogger _telemetry(AppEnv env) => RpcLogger(
  resource: const RpcTelemetryResource(serviceName: _serviceName),
  exporters: [
    RpcConsoleExporter.pretty(),
    if (env.otlpEndpoint case final endpoint?)
      RpcOtlpHttpExporter(endpoint: endpoint),
  ],
);

Future<void> main() async {
  final env = AppEnv.load();
  await const AppModule()
      .buildRpcApp(
        openApi: basicAppOpenApiOptions,
        docs: const RpcHttpDocsOptions(title: _docsTitle),
        middleware: [createCorsMiddleware()],
        staticAssets: const RpcHttpStaticOptions(
          directory: _staticAssetsFolder,
        ),
        health: const RpcHttpHealthOptions(),
        metrics: const RpcHttpMetricsOptions(),
        webSocket: const RpcWebSocketServerOptions(),
        bindings: const RpcContextBindings.empty().withValue(appEnvKey, env),
        observer: _telemetry(env),
      )
      .listen(env.port);
}

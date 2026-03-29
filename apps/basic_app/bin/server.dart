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
  );
  final server = await app.listen(3000);
  final baseUrl = 'http://127.0.0.1:${server.port}';
  print('RPC server listening on $baseUrl/rpc');
}

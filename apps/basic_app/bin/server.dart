import 'package:basic_app/basic_app.dart';

Future<void> main() async {
  final app = const AppModule().buildRpcApp();
  final server = await app.listen(3000);
  print(
    'RPC server listening on http://${server.address.host}:${server.port}/rpc',
  );
}

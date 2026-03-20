import 'package:basic_app/app.dart';

Future<void> main() async {
  final app = buildBasicApp();
  final server = await app.listen(3000);
  print(
    'RPC server listening on http://${server.address.host}:${server.port}/rpc',
  );
}

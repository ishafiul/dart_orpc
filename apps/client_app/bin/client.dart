import 'dart:convert';

import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';

Future<void> main(List<String> args) async {
  final userId = args.isNotEmpty ? args.first : '1';
  final baseUrl = args.length > 1 ? args[1] : 'http://127.0.0.1:3000';
  final transport = HttpRpcTransport(baseUrl: baseUrl);
  final client = AppClient(transport: transport);

  try {
    final user = await client.user.getById(GetUserDto(id: userId));
    final st = await client.user.status();
    print(jsonEncode(user.toJson()));
    print(jsonEncode(st.status));
  } on RpcException catch (error) {
    print(
      jsonEncode({
        'error': {'code': error.code.wireName, 'message': error.message},
      }),
    );
  } finally {
    transport.close();
  }
}

import 'dart:convert';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_client/dart_orpc_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  for (final code in RpcErrorCode.values) {
    test(
      'HTTP ${code.statusCode} ${code.wireName} decodes into typed exception',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode(
              RpcException(code: code, message: 'test').toResponse().toJson(),
            ),
            code.statusCode,
          ),
        );
        addTearDown(client.close);
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost',
          client: client,
        );
        await expectLater(
          transport.send(const RpcRequest(method: 'test.call')),
          throwsA(
            isA<RpcException>()
                .having((error) => error.code, 'code', code)
                .having((error) => error.statusCode, 'status', code.statusCode),
          ),
        );
      },
    );
  }
}

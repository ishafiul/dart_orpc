import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('createRpcHttpHandler', () {
    late RpcHttpHandler handler;

    setUp(() {
      final registry = RpcProcedureRegistry([
        RpcProcedure<JsonObject, JsonObject>(
          method: 'user.getById',
          decodeInput: (rawInput) =>
              expectJsonObject(rawInput, context: 'get user input'),
          encodeOutput: (output) => output,
          handler: (_, input) async {
            return {'id': input['id'], 'name': 'Ada Lovelace'};
          },
        ),
      ]);

      handler = createRpcHttpHandler(procedures: registry);
    });

    test('returns a data envelope for valid requests', () async {
      final response = await handler(
        RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          body: jsonEncode({
            'method': 'user.getById',
            'input': {'id': '123'},
          }),
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), {
        'data': {'id': '123', 'name': 'Ada Lovelace'},
      });
    });

    test('returns an rpc error envelope for unknown methods', () async {
      final response = await handler(
        RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          body: jsonEncode({
            'method': 'user.missing',
            'input': {'id': '123'},
          }),
        ),
      );

      expect(response.statusCode, HttpStatus.notFound);
      expect(jsonDecode(response.body), {
        'error': {
          'code': 'NOT_FOUND',
          'message': 'No RPC procedure registered for "user.missing".',
        },
      });
    });

    test('returns bad request for invalid json', () async {
      final response = await handler(
        const RpcHttpRequest(method: 'POST', path: '/rpc', body: '{'),
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(jsonDecode(response.body), {
        'error': {
          'code': 'BAD_REQUEST',
          'message': 'RPC request body must be valid JSON.',
        },
      });
    });

    test('returns method not allowed for non-POST RPC requests', () async {
      final response = await handler(
        const RpcHttpRequest(method: 'GET', path: '/rpc'),
      );

      expect(response.statusCode, HttpStatus.methodNotAllowed);
      expect(response.headers['allow'], 'POST');
    });
  });
}

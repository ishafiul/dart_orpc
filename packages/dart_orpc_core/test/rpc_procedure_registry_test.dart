import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  group('RpcProcedureRegistry', () {
    test('dispatches a registered procedure', () async {
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

      final response = await registry.dispatch(
        const RpcContext(headers: {}),
        const RpcRequest(method: 'user.getById', input: {'id': '123'}),
      );

      expect(response, {'id': '123', 'name': 'Ada Lovelace'});
    });

    test('throws not found for an unknown procedure', () async {
      final registry = RpcProcedureRegistry(const []);

      await expectLater(
        () => registry.dispatch(
          const RpcContext(headers: {}),
          const RpcRequest(method: 'user.missing'),
        ),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.notFound)
              .having(
                (error) => error.message,
                'message',
                'No RPC procedure registered for "user.missing".',
              ),
        ),
      );
    });

    test('throws when duplicate methods are registered', () {
      RpcProcedure<JsonObject, JsonObject> buildProcedure() {
        return RpcProcedure<JsonObject, JsonObject>(
          method: 'user.getById',
          decodeInput: (rawInput) =>
              expectJsonObject(rawInput, context: 'get user input'),
          encodeOutput: (output) => output,
          handler: (_, input) => input,
        );
      }

      expect(
        () => RpcProcedureRegistry([buildProcedure(), buildProcedure()]),
        throwsStateError,
      );
    });
  });
}

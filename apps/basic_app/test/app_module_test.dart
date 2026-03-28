import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  test(
    'generated module registry dispatches the annotated RPC method',
    () async {
      final app = buildBasicApp();

      final response = await app.procedures.dispatch(
        const RpcContext(headers: {}),
        const RpcRequest(method: 'user.getById', input: {'id': '1'}),
      );

      expect(response, {'id': '1', 'name': 'Ada Lovelace'});
    },
  );

  test(
    'generated module registry dispatches a zero-input RPC method',
    () async {
      final app = buildBasicApp();

      final response = await app.procedures.dispatch(
        const RpcContext(headers: {}),
        const RpcRequest(method: 'user.status'),
      );

      expect(response, {'status': 'ready'});
    },
  );

  test(
    'generated procedure metadata includes the REST route with path and query bindings',
    () {
      final metadata = buildBasicAppProcedureMetadata();
      final procedure = metadata['user.getByIdRest'];

      expect(procedure, isNotNull);
      expect(procedure!.controllerNamespace, 'user');
      expect(procedure.methodName, 'getByIdRest');
      expect(procedure.path, isNotNull);
      expect(procedure.path!.method, 'GET');
      expect(procedure.path!.path, '/users/:id');
      expect(procedure.inputTypeCode, isNull);
      expect(procedure.outputTypeCode, 'UserResponseDto');
      expect(
        procedure.description,
        'Resolve a user by id from the REST-style example route.',
      );
      expect(procedure.tags, ['user', 'example']);
      expect(procedure.parameters, hasLength(2));
      expect(procedure.parameters.first.parameterName, 'id');
      expect(procedure.parameters.first.wireName, 'id');
      expect(
        procedure.parameters.first.source,
        ProcedureParameterSourceKind.path,
      );
      expect(procedure.parameters[1].parameterName, 'view');
      expect(procedure.parameters[1].wireName, 'include');
      expect(
        procedure.parameters[1].source,
        ProcedureParameterSourceKind.query,
      );
    },
  );
}

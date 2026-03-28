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
      final procedure = metadata['user.getById'];

      expect(procedure, isNotNull);
      expect(procedure!.controllerNamespace, 'user');
      expect(procedure.methodName, 'getById');
      expect(procedure.path, isNotNull);
      expect(procedure.path!.method, 'GET');
      expect(procedure.path!.path, '/users/:id');
      expect(procedure.inputTypeCode, 'GetUserDto');
      expect(procedure.outputTypeCode, 'UserResponseDto');
      expect(
        procedure.description,
        'Resolve a user by id from the shared RPC and REST method.',
      );
      expect(procedure.tags, ['user', 'example']);
      expect(procedure.parameters, hasLength(2));
      expect(procedure.parameters.first.parameterName, 'id');
      expect(procedure.parameters.first.wireName, 'id');
      expect(
        procedure.parameters.first.source,
        ProcedureParameterSourceKind.path,
      );
      expect(procedure.parameters[1].parameterName, 'include');
      expect(procedure.parameters[1].wireName, 'include');
      expect(
        procedure.parameters[1].source,
        ProcedureParameterSourceKind.query,
      );
    },
  );

  test('generated OpenAPI document exposes the REST path and DTO schemas', () {
    final document = buildBasicAppOpenApiDocument();
    final paths = document['paths'] as Map<String, Object?>;
    final components =
        ((document['components'] as Map<String, Object?>)['schemas']
            as Map<String, Object?>);

    expect(paths.containsKey('/users/{id}'), isTrue);
    expect(
      ((paths['/users/{id}'] as Map<String, Object?>)['get']
          as Map<String, Object?>)['operationId'],
      'user.getById',
    );
    expect(components.containsKey('GetUserDto'), isTrue);
    expect(components.containsKey('UserResponseDto'), isTrue);
    expect(components.containsKey('RpcErrorResponse'), isTrue);
  });
}

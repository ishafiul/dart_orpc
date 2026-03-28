import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Procedure metadata types', () {
    test('store the expected procedure and parameter fields', () {
      const metadata = ProcedureMetadata(
        rpcMethod: 'user.getById',
        controllerNamespace: 'user',
        methodName: 'getById',
        inputTypeCode: 'GetUserDto',
        outputTypeCode: 'UserResponseDto',
        path: RestProcedureMetadata(method: 'GET', path: '/users/:id'),
        description: 'Fetch a user by id.',
        tags: ['user', 'read'],
        parameters: [
          ProcedureParameterMetadata(
            parameterName: 'id',
            wireName: 'id',
            source: ProcedureParameterSourceKind.path,
            typeCode: 'String',
          ),
          ProcedureParameterMetadata(
            parameterName: 'tenantId',
            wireName: 'x-tenant-id',
            source: ProcedureParameterSourceKind.header,
            typeCode: 'String?',
          ),
          ProcedureParameterMetadata(
            parameterName: 'body',
            wireName: 'body',
            source: ProcedureParameterSourceKind.body,
            typeCode: 'GetUserDto',
          ),
        ],
      );

      expect(metadata.rpcMethod, 'user.getById');
      expect(metadata.controllerNamespace, 'user');
      expect(metadata.methodName, 'getById');
      expect(metadata.inputTypeCode, 'GetUserDto');
      expect(metadata.outputTypeCode, 'UserResponseDto');
      expect(metadata.path!.method, 'GET');
      expect(metadata.path!.path, '/users/:id');
      expect(metadata.description, 'Fetch a user by id.');
      expect(metadata.tags, ['user', 'read']);
      expect(metadata.parameters, hasLength(3));
      expect(metadata.parameters.first.parameterName, 'id');
      expect(metadata.parameters.first.wireName, 'id');
      expect(
        metadata.parameters.first.source,
        ProcedureParameterSourceKind.path,
      );
      expect(metadata.parameters.first.typeCode, 'String');
      expect(metadata.parameters[1].wireName, 'x-tenant-id');
      expect(
        metadata.parameters[1].source,
        ProcedureParameterSourceKind.header,
      );
    });

    test('indexes metadata by RPC method', () {
      final registry = ProcedureMetadataRegistry([
        const ProcedureMetadata(
          rpcMethod: 'user.getById',
          controllerNamespace: 'user',
          methodName: 'getById',
          inputTypeCode: 'GetUserDto',
          outputTypeCode: 'UserResponseDto',
          parameters: [
            ProcedureParameterMetadata(
              parameterName: 'input',
              wireName: 'input',
              source: ProcedureParameterSourceKind.rpcInput,
              typeCode: 'GetUserDto',
            ),
          ],
        ),
      ]);

      expect(registry.methods, ['user.getById']);
      expect(registry.procedures, hasLength(1));
      expect(registry['user.getById']?.outputTypeCode, 'UserResponseDto');
    });

    test('rejects duplicate RPC methods', () {
      expect(
        () => ProcedureMetadataRegistry([
          const ProcedureMetadata(
            rpcMethod: 'user.getById',
            controllerNamespace: 'user',
            methodName: 'getById',
            outputTypeCode: 'UserResponseDto',
          ),
          const ProcedureMetadata(
            rpcMethod: 'user.getById',
            controllerNamespace: 'user',
            methodName: 'fetchById',
            outputTypeCode: 'UserResponseDto',
          ),
        ]),
        throwsStateError,
      );
    });
  });
}

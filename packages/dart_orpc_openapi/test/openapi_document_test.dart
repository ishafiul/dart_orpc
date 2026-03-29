import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_openapi/dart_orpc_openapi.dart';
import 'package:luthor/luthor.dart';
import 'package:test/test.dart';

void main() {
  group('Given createOpenApiDocument', () {
    test(
      'When passed REST procedure metadata and Luthor schemas then it builds an OpenAPI document with components',
      () {
        final document = createOpenApiDocument(
          title: 'Example API',
          procedures: ProcedureMetadataRegistry([
            const ProcedureMetadata(
              rpcMethod: 'user.getByIdRest',
              controllerNamespace: 'user',
              methodName: 'getByIdRest',
              path: RestProcedureMetadata(method: 'GET', path: '/users/:id'),
              outputTypeCode: 'UserResponseDto',
              description: 'Resolve a user by id.',
              tags: ['user'],
              parameters: [
                ProcedureParameterMetadata(
                  parameterName: 'id',
                  wireName: 'id',
                  source: ProcedureParameterSourceKind.path,
                  typeCode: 'String',
                ),
                ProcedureParameterMetadata(
                  parameterName: 'include',
                  wireName: 'include',
                  source: ProcedureParameterSourceKind.query,
                  typeCode: 'String?',
                ),
                ProcedureParameterMetadata(
                  parameterName: 'tenantId',
                  wireName: 'x-tenant-id',
                  source: ProcedureParameterSourceKind.header,
                  typeCode: 'String?',
                ),
              ],
            ),
          ]),
          schemas: OpenApiSchemaRegistry([
            OpenApiSchemaComponent(
              name: 'UserResponseDto',
              validator: l.withName('UserResponseDto').schema({
                'id': l.string().min(1).required(),
                'name': l.string().min(1).required(),
              }),
            ),
          ]),
        );

        expect(document['openapi'], '3.0.3');
        expect(document['info'], {'title': 'Example API', 'version': '1.0.0'});

        final paths = document['paths'] as Map<String, Object?>;
        final operation =
            (paths['/users/{id}'] as Map<String, Object?>)['get']
                as Map<String, Object?>;
        final parameters = operation['parameters'] as List<Object?>;
        final successResponse =
            ((operation['responses'] as Map<String, Object?>)['200']
                    as Map<String, Object?>)['content']
                as Map<String, Object?>;
        final schemas =
            ((document['components'] as Map<String, Object?>)['schemas']
                as Map<String, Object?>);

        expect(operation['operationId'], 'user.getByIdRest');
        expect(operation['description'], 'Resolve a user by id.');
        expect(operation['tags'], ['user']);
        expect(parameters, hasLength(3));
        expect(parameters.first, {
          'name': 'id',
          'in': 'path',
          'required': true,
          'schema': {'type': 'string'},
          'x-rpc-parameter': 'id',
          'x-rpc-method': 'user.getByIdRest',
        });
        expect(((parameters[1] as Map<String, Object?>)['required']), isFalse);
        expect(parameters[2], {
          'name': 'x-tenant-id',
          'in': 'header',
          'required': false,
          'schema': {'type': 'string'},
          'x-rpc-parameter': 'tenantId',
          'x-rpc-method': 'user.getByIdRest',
        });
        expect(successResponse, {
          'application/json': {
            'schema': {'\$ref': '#/components/schemas/UserResponseDto'},
          },
        });
        expect(schemas['UserResponseDto'], {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'minLength': 1},
            'name': {'type': 'string', 'minLength': 1},
          },
          'required': ['id', 'name'],
        });
        expect(schemas['RpcErrorResponse'], isNotNull);
      },
    );

    test(
      'When building Scalar docs HTML then it embeds the configured OpenAPI URL',
      () {
        final html = createScalarHtml(
          title: 'Example API Docs',
          openApiPath: '/openapi.json',
        );

        expect(html, contains('<title>Example API Docs</title>'));
        expect(html, contains('data-url="/openapi.json"'));
        expect(html, contains('@scalar/api-reference'));
      },
    );

    test(
      'When OpenAPI servers are provided then the document includes the servers array',
      () {
        final document = createOpenApiDocument(
          title: 'Example API',
          servers: const [
            OpenApiServer(
              url: 'https://api.example.com',
              description: 'Production',
            ),
            OpenApiServer(url: 'http://localhost:3000'),
          ],
          procedures: ProcedureMetadataRegistry(const []),
        );

        expect(document['servers'], [
          {'url': 'https://api.example.com', 'description': 'Production'},
          {'url': 'http://localhost:3000'},
        ]);
      },
    );

    test(
      'When a REST operation shares one input DTO between path, header, and body then the request body schema excludes externally-bound fields',
      () {
        final document = createOpenApiDocument(
          title: 'Example API',
          procedures: ProcedureMetadataRegistry([
            const ProcedureMetadata(
              rpcMethod: 'user.update',
              controllerNamespace: 'user',
              methodName: 'update',
              path: RestProcedureMetadata(method: 'POST', path: '/users/:id'),
              inputTypeCode: 'UpdateUserDto',
              outputTypeCode: 'UserResponseDto',
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
                  parameterName: 'input',
                  wireName: 'input',
                  source: ProcedureParameterSourceKind.body,
                  typeCode: 'UpdateUserDto',
                ),
              ],
            ),
          ]),
          schemas: OpenApiSchemaRegistry([
            OpenApiSchemaComponent(
              name: 'UpdateUserDto',
              validator: l.withName('UpdateUserDto').schema({
                'id': l.string().min(1).required(),
                'tenantId': l.string(),
                'name': l.string().min(1).required(),
                'nickname': l.string(),
              }),
            ),
            OpenApiSchemaComponent(
              name: 'UserResponseDto',
              validator: l.withName('UserResponseDto').schema({
                'id': l.string().min(1).required(),
                'name': l.string().min(1).required(),
              }),
            ),
          ]),
        );

        final operation =
            ((((document['paths'] as Map<String, Object?>)['/users/{id}']
                        as Map<String, Object?>)['post']
                    as Map<String, Object?>)['requestBody']
                as Map<String, Object?>);
        final schema =
            (((operation['content'] as Map<String, Object?>)['application/json']
                    as Map<String, Object?>)['schema']
                as Map<String, Object?>);

        expect(operation['required'], isTrue);
        expect(
          (schema['properties'] as Map<String, Object?>).containsKey('id'),
          isFalse,
        );
        expect(
          (schema['properties'] as Map<String, Object?>).containsKey(
            'tenantId',
          ),
          isFalse,
        );
        expect(
          (schema['properties'] as Map<String, Object?>).containsKey('name'),
          isTrue,
        );
        expect((schema['required'] as List<Object?>), ['name']);
      },
    );
  });
}

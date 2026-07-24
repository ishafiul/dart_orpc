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
      'When a server stream has an SSE mapping then OpenAPI documents its event schema and terminal events',
      () {
        final document = createOpenApiDocument(
          title: 'Streaming API',
          procedures: ProcedureMetadataRegistry([
            const ProcedureMetadata(
              rpcMethod: 'chat.watchMessages',
              controllerNamespace: 'chat',
              methodName: 'watchMessages',
              kind: RpcProcedureKind.serverStream,
              path: RestProcedureMetadata(
                method: 'GET',
                path: '/channels/:channelId/messages',
                responseKind: RestResponseKind.sse,
              ),
              outputTypeCode: 'MessageDto',
            ),
            const ProcedureMetadata(
              rpcMethod: 'chat.websocketOnly',
              controllerNamespace: 'chat',
              methodName: 'websocketOnly',
              kind: RpcProcedureKind.serverStream,
              outputTypeCode: 'MessageDto',
            ),
          ]),
          schemas: OpenApiSchemaRegistry([
            OpenApiSchemaComponent(
              name: 'MessageDto',
              validator: l.withName('MessageDto').schema({
                'id': l.string().required(),
                'text': l.string().required(),
              }),
            ),
          ]),
        );

        final paths = document['paths'] as Map<String, Object?>;
        final operation =
            (paths['/channels/{channelId}/messages']
                    as Map<String, Object?>)['get']
                as Map<String, Object?>;
        final success =
            (operation['responses'] as Map<String, Object?>)['200']
                as Map<String, Object?>;
        final extension =
            operation['x-dart-orpc-stream'] as Map<String, Object?>;

        expect((success['content'] as Map<String, Object?>).keys, [
          'text/event-stream',
        ]);
        expect(extension, {
          'kind': 'server-stream',
          'eventSchema': {'\$ref': '#/components/schemas/MessageDto'},
          'terminalEvents': {
            'complete': 'dart-orpc-complete',
            'error': 'dart-orpc-error',
          },
        });
        expect(paths.keys, hasLength(1));
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

    test(
      'When schema components use scalar constraints, lists, and maps then OpenAPI preserves their shapes',
      () {
        final registry = OpenApiSchemaRegistry([
          OpenApiSchemaComponent(
            name: 'Constraints',
            validator: l.withName('Constraints').schema({
              'bounded': l.string().min(2).max(8),
              'exact': l.string().length(4),
              'email': l.string().email(),
              'date': l.string().dateTime(),
              'uri': l.string().uri(),
              'uuid': l.string().uuid(),
              'pattern': l.string().regex(r'^[a-z]+$'),
              'integer': l.int().min(1).max(9),
              'number': l.double().min(0.5).max(9.5),
              'flag': l.boolean(),
              'emptyList': l.list(),
              'strings': l.list(validators: [l.string()]),
              'mixed': l.list(validators: [l.string(), l.int()]),
              'map': l.map(valueValidator: l.boolean()),
            }),
          ),
        ]);
        final document = createOpenApiDocument(
          title: 'Constraints API',
          description: 'All supported validation shapes.',
          procedures: ProcedureMetadataRegistry(const []),
          schemas: registry,
        );
        final schemas =
            (document['components'] as Map<String, Object?>)['schemas']
                as Map<String, Object?>;
        final constraints = schemas['Constraints'] as Map<String, Object?>;
        final properties = constraints['properties'] as Map<String, Object?>;

        expect(registry.names, ['Constraints']);
        expect(registry['Constraints'], isNotNull);
        expect(document['info'], {
          'title': 'Constraints API',
          'version': '1.0.0',
          'description': 'All supported validation shapes.',
        });
        expect(properties['bounded'], {
          'type': 'string',
          'minLength': 2,
          'maxLength': 8,
        });
        expect(properties['exact'], {
          'type': 'string',
          'minLength': 4,
          'maxLength': 4,
        });
        expect((properties['email'] as Map)['format'], 'email');
        expect((properties['date'] as Map)['format'], 'date-time');
        expect((properties['uri'] as Map)['format'], 'uri');
        expect((properties['uuid'] as Map)['format'], 'uuid');
        expect((properties['pattern'] as Map)['pattern'], r'^[a-z]+$');
        expect(properties['integer'], {
          'type': 'integer',
          'minimum': 1,
          'maximum': 9,
        });
        expect(properties['number'], {
          'type': 'number',
          'minimum': 0.5,
          'maximum': 9.5,
        });
        expect(properties['flag'], {'type': 'boolean'});
        expect(properties['emptyList'], {'type': 'array', 'items': {}});
        expect(properties['strings'], {
          'type': 'array',
          'items': {'type': 'string'},
        });
        expect(properties['mixed'], {
          'type': 'array',
          'items': {
            'oneOf': [
              {'type': 'string'},
              {'type': 'integer'},
            ],
          },
        });
        expect(properties['map'], {
          'type': 'object',
          'additionalProperties': {'type': 'boolean'},
        });
      },
    );

    test(
      'When contracts use built-in and unknown type codes then OpenAPI emits stable fallback schemas',
      () {
        const typeCodes = [
          'int',
          'double',
          'num',
          'bool',
          'JsonObject',
          'Map<String, Object?>',
          'List<String>',
          'UnknownDto',
        ];
        final document = createOpenApiDocument(
          title: 'Types API',
          procedures: ProcedureMetadataRegistry([
            for (var index = 0; index < typeCodes.length; index++)
              ProcedureMetadata(
                rpcMethod: 'types.$index',
                controllerNamespace: 'types',
                methodName: 'type$index',
                path: RestProcedureMetadata(
                  method: index.isEven ? 'GET' : 'POST',
                  path: '/types/$index',
                ),
                outputTypeCode: typeCodes[index],
              ),
          ]),
        );
        final paths = document['paths'] as Map<String, Object?>;
        Map<String, Object?> schemaAt(int index) {
          final operation =
              (paths['/types/$index'] as Map<String, Object?>)[index.isEven
                      ? 'get'
                      : 'post']
                  as Map<String, Object?>;
          final responses = operation['responses'] as Map<String, Object?>;
          final response = responses['200'] as Map<String, Object?>;
          final content = response['content'] as Map<String, Object?>;
          final mediaType = content['application/json'] as Map<String, Object?>;
          return mediaType['schema'] as Map<String, Object?>;
        }

        final schemas = [
          for (var index = 0; index < typeCodes.length; index++)
            schemaAt(index),
        ];

        expect(schemas, [
          {'type': 'integer'},
          {'type': 'number'},
          {'type': 'number'},
          {'type': 'boolean'},
          {'type': 'object'},
          {'type': 'object'},
          {'type': 'array', 'items': {}},
          {'type': 'object'},
        ]);
      },
    );

    test(
      'When duplicate schema names are registered then construction fails',
      () {
        final component = OpenApiSchemaComponent(
          name: 'Duplicate',
          validator: l.withName('Duplicate').schema({}),
        );

        expect(
          () => OpenApiSchemaRegistry([component, component]),
          throwsStateError,
        );
      },
    );

    test(
      'When Scalar values contain HTML then text and attributes are escaped',
      () {
        final html = createScalarHtml(
          title: 'Docs <unsafe> & useful',
          openApiPath: '/openapi?label="one"&kind=\'two\'',
        );

        expect(html, contains('Docs &lt;unsafe&gt; &amp; useful'));
        expect(
          html,
          contains(
            'data-url="/openapi?label=&quot;one&quot;&amp;kind=&#39;two&#39;"',
          ),
        );
      },
    );
  });
}

import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  group('Given the dart_orpc facade package', () {
    test(
      'When importing it then the public runtime APIs are available',
      () async {
        const module = Module(imports: [Uri], exports: [String]);
        const controller = Controller('user');
        const useGuards = UseGuards([_FacadeGuard]);
        const rpcMetadata = RpcMetadata('permissions');
        const method = RpcMethod(
          name: 'getById',
          path: RestMapping.get('users/:id'),
          description: 'Fetch a user by id.',
          tags: ['user', 'read'],
        );
        const inputAnnotation = RpcInput(
          binding: RpcInputBinding(
            path: [RpcInputField('id')],
            headers: [RpcInputField('tenantId', 'x-tenant-id')],
          ),
        );
        const pathParam = PathParam('id');
        const queryParam = QueryParam('include');
        const body = Body();
        const fromPath = FromPath('userId');
        const fromQuery = FromQuery('view');
        const fromHeader = FromHeader('x-tenant-id');
        const boundField = RpcInputField<String>('id', 'userId');
        const context = RpcContext(headers: {'x-trace-id': 'trace-1'});
        const request = RpcRequest(method: 'user.getById', input: {'id': '1'});
        const successResponse = RpcSuccessResponse(data: {'id': '1'});
        const errorResponse = RpcErrorResponse(
          error: RpcErrorBody(code: 'NOT_FOUND', message: 'missing'),
        );
        final procedureMetadata = ProcedureMetadataRegistry([
          const ProcedureMetadata(
            rpcMethod: 'user.getById',
            controllerNamespace: 'user',
            methodName: 'getById',
            outputTypeCode: 'UserResponseDto',
            path: RestProcedureMetadata(method: 'GET', path: '/users/:id'),
            description: 'Fetch a user by id.',
            tags: ['user', 'read'],
            guardTypes: ['AuthGuard'],
            customMetadata: [
              ProcedureCustomMetadata(
                key: 'permissions',
                value: {
                  'anyOf': ['user.read', 'user.admin'],
                  'allOf': ['tenant.active'],
                },
              ),
            ],
            parameters: [
              ProcedureParameterMetadata(
                parameterName: 'id',
                wireName: 'id',
                source: ProcedureParameterSourceKind.path,
                typeCode: 'String',
              ),
            ],
          ),
        ]);
        final openApiSchemaRegistry = OpenApiSchemaRegistry([
          OpenApiSchemaComponent(
            name: 'UserResponseDto',
            validator: l.withName('UserResponseDto').schema({
              'id': l.string().required(),
            }),
          ),
        ]);
        const openApiServer = OpenApiServer(url: 'http://localhost:3000');
        const openApiOptions = OpenApiDocumentOptions(
          title: 'Facade API',
          description: 'Facade docs',
          servers: [openApiServer],
        );
        final openApiDocument = createOpenApiDocument(
          title: 'Facade API',
          servers: const [openApiServer],
          procedures: procedureMetadata,
          schemas: openApiSchemaRegistry,
        );
        final scalarHtml = createScalarHtml(title: 'Facade API');
        const docsBasicAuth = RpcHttpBasicAuth(
          username: 'docs',
          password: 'secret',
        );
        const docsOptions = RpcHttpDocsOptions(
          title: 'Facade Docs',
          basicAuth: docsBasicAuth,
        );
        const httpRequest = RpcHttpRequest(method: 'POST', path: '/rpc');
        const httpResponse = RpcHttpResponse(statusCode: 200);
        final middleware = <RpcHttpMiddleware>[(next) => next];
        final guardCalls = <String>[];
        final guard = _FacadeGuard(guardCalls);
        final restRoutes = RestRouteRegistry(const []);
        final transport = HttpRpcTransport(baseUrl: 'http://localhost:3000');
        final caller = RpcCaller(const _StaticTransport({'ok': true}));
        final optionalQuery = decodeRestScalarParameter<String?>(
          rawValue: null,
          source: 'query parameter',
          name: 'include',
          route: 'GET /users/:id',
        );

        final result = await caller.call<Map<String, Object?>>(
          method: 'health.check',
          decode: (json) => expectJsonObject(json, context: 'health response'),
        );
        await runRpcGuards(
          [guard],
          rpcContext: context,
          procedure: procedureMetadata['user.getById']!,
          input: request.input,
        );

        expect(module.imports, [Uri]);
        expect(module.controllers, isEmpty);
        expect(module.exports, [String]);
        expect(controller.namespace, 'user');
        expect(useGuards.guards, [_FacadeGuard]);
        expect(rpcMetadata.key, 'permissions');
        expect(method.name, 'getById');
        expect(method.path?.method, 'GET');
        expect(method.path?.path, '/users/:id');
        expect(method.description, 'Fetch a user by id.');
        expect(method.tags, ['user', 'read']);
        expect(inputAnnotation.binding?.path.single.field, 'id');
        expect(inputAnnotation.binding?.headers.single.name, 'x-tenant-id');
        expect(pathParam.name, 'id');
        expect(queryParam.name, 'include');
        expect(body, isA<Body>());
        expect(fromPath.name, 'userId');
        expect(fromQuery.name, 'view');
        expect(fromHeader.name, 'x-tenant-id');
        expect(boundField.field, 'id');
        expect(boundField.name, 'userId');
        expect(context.headers['x-trace-id'], 'trace-1');
        expect(expectNoRpcInput(null, context: 'health.check'), isNull);
        expect(request.toJson(), {
          'method': 'user.getById',
          'input': {'id': '1'},
        });
        expect(successResponse.toJson(), {
          'data': {'id': '1'},
        });
        expect(errorResponse.toJson(), {
          'error': {'code': 'NOT_FOUND', 'message': 'missing'},
        });
        expect(httpRequest.path, '/rpc');
        expect(httpResponse.statusCode, 200);
        expect(middleware, hasLength(1));
        expect(guardCalls, ['user.getById']);
        expect(restRoutes.routes, isEmpty);
        expect(transport.endpointUri.toString(), 'http://localhost:3000/rpc');
        expect(procedureMetadata['user.getById']?.methodName, 'getById');
        expect(
          procedureMetadata['user.getById']?.description,
          'Fetch a user by id.',
        );
        expect(
          procedureMetadata['user.getById']?.firstMetadataValue('permissions'),
          {
            'anyOf': ['user.read', 'user.admin'],
            'allOf': ['tenant.active'],
          },
        );
        expect(openApiSchemaRegistry.names, ['UserResponseDto']);
        expect(openApiDocument['paths'], isNotEmpty);
        expect((openApiDocument['servers'] as List<Object?>).single, {
          'url': 'http://localhost:3000',
        });
        expect(openApiOptions.title, 'Facade API');
        expect(docsBasicAuth.username, 'docs');
        expect(docsOptions.title, 'Facade Docs');
        expect(scalarHtml, contains('@scalar/api-reference'));
        expect(optionalQuery, isNull);
        expect(result, {'ok': true});

        transport.close();
      },
    );
  });
}

final class _StaticTransport implements RpcTransport {
  const _StaticTransport(this.response);

  final Object? response;

  @override
  Future<Object?> send(RpcRequest request) async => response;
}

final class _FacadeGuard implements RpcGuard {
  const _FacadeGuard(this.calls);

  final List<String> calls;

  @override
  void canActivate(RpcGuardContext context) {
    calls.add(context.procedure.rpcMethod);
  }
}

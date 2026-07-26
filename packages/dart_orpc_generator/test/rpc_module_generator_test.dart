import 'package:build/build.dart';
import 'package:test/test.dart';

import 'support/generator_test_harness.dart';

void main() {
  group('Given RpcModuleGenerator', () {
    test(
      'When the builder runs for a valid module then it emits registry, metadata, app, and client code',
      () async {
        final run = await runModuleBuilder(_validRpcModuleSource);

        expect(run.succeeded, isTrue);
        expect(run.outputs, contains(AssetId('a', 'lib/example.orpc.dart')));

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains(
            'RpcProcedureRegistry _\$createAppModuleProcedureRegistry() {',
          ),
        );
        expect(generatedOutput, contains('class _\$AppModuleContainer {'));
        expect(
          generatedOutput,
          contains('_\$AppModuleContainer _\$createAppModuleContainer() {'),
        );
        expect(
          generatedOutput,
          contains(
            'RpcProcedureRegistry _\$createAppModuleProcedureRegistryFromContainer(',
          ),
        );
        expect(
          generatedOutput,
          contains(
            'ProcedureMetadataRegistry _\$createAppModuleProcedureMetadataRegistry() {',
          ),
        );
        expect(
          generatedOutput,
          contains(
            'OpenApiSchemaRegistry _\$createAppModuleOpenApiSchemaRegistry() {',
          ),
        );
        expect(
          generatedOutput,
          contains(
            'JsonObject _\$createAppModuleOpenApiDocument({OpenApiDocumentOptions? options}) {',
          ),
        );
        expect(
          generatedOutput,
          contains('RestRouteRegistry _\$createAppModuleRestRouteRegistry() {'),
        );
        expect(
          generatedOutput,
          contains(
            'RestRouteRegistry _\$createAppModuleRestRouteRegistryFromContainer(',
          ),
        );
        expect(generatedOutput, contains("method: 'user.getById',"));
        expect(generatedOutput, contains("rpcMethod: 'user.getById',"));
        expect(
          generatedOutput,
          contains('source: ProcedureParameterSourceKind.rpcInput,'),
        );
        expect(generatedOutput, contains("outputTypeCode: 'UserResponseDto',"));
        expect(generatedOutput, contains("methodName: 'status',"));
        expect(
          generatedOutput,
          contains('RpcUnaryProcedure<Null, UserStatusDto>('),
        );
        expect(
          generatedOutput,
          contains('RpcHttpApp dartOrpcBuildAppModuleRpcApp({'),
        );
        expect(
          generatedOutput,
          contains('extension DartOrpcAppModuleGenerated on AppModule {'),
        );
        expect(generatedOutput, contains('RpcHttpApp buildRpcApp({'));
        expect(generatedOutput, contains('dartOrpcBuildAppModuleRpcApp('));
        expect(
          generatedOutput,
          contains(
            'JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>',
          ),
        );
        expect(
          generatedOutput,
          contains('dartOrpcCreateAppModuleOpenApiDocument(options: options);'),
        );
        expect(
          generatedOutput,
          contains('final runtime = _\$createAppModuleRuntime();'),
        );
        expect(generatedOutput, contains('procedures: runtime.procedures'));
        expect(generatedOutput, contains('restRoutes: runtime.restRoutes'));
        expect(
          generatedOutput,
          contains(
            '_\$createAppModuleProcedureRegistryFromContainer(container);',
          ),
        );
        expect(
          generatedOutput,
          contains(
            '_\$createAppModuleRestRouteRegistryFromContainer(container);',
          ),
        );
        expect(
          generatedOutput,
          contains('openApiDocument: _\$createAppModuleOpenApiDocument('),
        );
        expect(generatedOutput, contains('docsHtml:'));
        expect(generatedOutput, contains('effectiveDocs.html ??'));
        expect(
          generatedOutput,
          contains('title: effectiveDocs.title ?? effectiveOpenApiTitle,'),
        );
        expect(generatedOutput, contains('openApiPath: effectiveOpenApiPath,'));
        expect(generatedOutput, contains('docsPath: effectiveDocs.docsPath,'));
        expect(
          generatedOutput,
          contains('docsBasicAuth: effectiveDocs.basicAuth,'),
        );
        expect(generatedOutput, contains('middleware: middleware,'));
        expect(
          countMatches(generatedOutput, 'final userService = UserService();'),
          1,
        );
        expect(
          countMatches(
            generatedOutput,
            'final userController = UserController(userService);',
          ),
          1,
        );
        expect(generatedOutput, contains('class AppClient {'));
        expect(
          generatedOutput,
          contains('late final user = UserClient(_transports);'),
        );
        expect(generatedOutput, contains('Future<UserStatusDto> status() {'));
      },
    );

    test(
      'When client DTOs live in a separate contract library then the generated module library re-exports that contract library',
      () async {
        final run = await runModuleBuilder(
          _splitContractModuleSource,
          additionalSources: {'lib/contracts.dart': _splitContractDtoSource},
        );

        expect(run.succeeded, isTrue);
        expect(
          run.generatedOutput,
          contains("export 'package:a/contracts.dart';"),
        );
      },
    );

    test(
      'When unary methods return scalars or void then generated codecs preserve their public contracts',
      () async {
        final run = await runModuleBuilder(_scalarAndVoidOutputModuleSource);

        expect(run.succeeded, isTrue);
        final output = run.generatedOutput;
        expect(output, contains('RpcUnaryProcedure<Null, String>('));
        expect(output, contains('encodeOutput: (output) => output,'));
        expect(output, contains('Future<String> greeting() {'));
        expect(output, contains('decode: (json) => json as String'));
        expect(output, contains('RpcUnaryProcedure<Null, Null>('));
        expect(output, contains("outputTypeCode: 'void',"));
        expect(output, contains('Future<void> clear() async {'));
        expect(output, contains('Future<void> clearLater() async {'));
        expect(output, contains('decode: (_) => null'));
        expect(output, contains('container.statusController.clear();'));
        expect(
          output,
          contains('await container.statusController.clearLater();'),
        );
      },
    );

    test(
      'When controller and method guards are declared then the generated module resolves guard providers and runs them for both RPC and REST',
      () async {
        final run = await runModuleBuilder(_guardedRpcModuleSource);

        expect(run.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(generatedOutput, contains('final authGuard = AuthGuard();'));
        expect(
          generatedOutput,
          contains('final userReadGuard = UserReadGuard(userService);'),
        );
        expect(
          generatedOutput,
          contains("metadata: metadataRegistry['user.getById']!,"),
        );
        expect(
          countMatches(
            generatedOutput,
            'guards: [container.authGuard, container.userReadGuard],',
          ),
          2,
        );
        expect(
          generatedOutput,
          contains("guardTypes: ['AuthGuard', 'UserReadGuard'],"),
        );
        expect(generatedOutput, contains('customMetadata: ['));
        expect(generatedOutput, contains("'allOf': ['tenant.active'],"));
        expect(
          generatedOutput,
          contains("'anyOf': ['user.read', 'user.admin'],"),
        );
      },
    );

    test(
      'When a module includes a REST-enabled method then it emits procedure metadata for explicit REST parameters',
      () async {
        final run = await runModuleBuilder(_validRestMetadataSource);

        expect(run.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains(
            'ProcedureMetadataRegistry _\$createAppModuleProcedureMetadataRegistry() {',
          ),
        );
        expect(
          generatedOutput,
          contains(
            'OpenApiSchemaRegistry _\$createAppModuleOpenApiSchemaRegistry() {',
          ),
        );
        expect(
          generatedOutput,
          contains(
            'JsonObject _\$createAppModuleOpenApiDocument({OpenApiDocumentOptions? options}) {',
          ),
        );
        expect(
          generatedOutput,
          contains('RestRouteRegistry _\$createAppModuleRestRouteRegistry() {'),
        );
        expect(generatedOutput, contains("rpcMethod: 'user.getById',"));
        expect(generatedOutput, contains("rpcMethod: 'user.findBySlug',"));
        expect(
          generatedOutput,
          contains(
            "path: RestProcedureMetadata(method: 'GET', path: '/users/:id'),",
          ),
        );
        expect(
          generatedOutput,
          contains("description: 'Find a user by route-bound id.',"),
        );
        expect(generatedOutput, contains("tags: ['user', 'lookup'],"));
        expect(
          generatedOutput,
          contains(
            'OpenApiSchemaRegistry _\$createAppModuleOpenApiSchemaRegistry() {',
          ),
        );
        expect(generatedOutput, contains("parameterName: 'id',"));
        expect(generatedOutput, contains("wireName: 'id',"));
        expect(
          generatedOutput,
          contains('source: ProcedureParameterSourceKind.path,'),
        );
        expect(generatedOutput, contains("parameterName: 'view',"));
        expect(generatedOutput, contains("wireName: 'include',"));
        expect(
          generatedOutput,
          contains('source: ProcedureParameterSourceKind.query,'),
        );
        expect(generatedOutput, contains("method: 'GET',"));
        expect(generatedOutput, contains("path: '/users/:id',"));
        expect(
          generatedOutput,
          contains('final id = decodeRestScalarParameter<String>('),
        );
        expect(generatedOutput, contains("rawValue: pathParameters['id'],"));
        expect(
          generatedOutput,
          contains('final view = decodeRestScalarParameter<String>('),
        );
        expect(
          generatedOutput,
          contains("rawValue: request.queryParameters['include'],"),
        );
        expect(
          generatedOutput,
          contains('RpcUnaryProcedure<GetUserDto, UserResponseDto>('),
        );
      },
    );

    test(
      'When a REST-enabled method uses DTO field source annotations then it emits shared path, query, and header bindings from the same procedure',
      () async {
        final run = await runModuleBuilder(_sharedRpcAndRestGetSource);

        expect(run.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(generatedOutput, contains("method: 'user.getById',"));
        expect(
          generatedOutput,
          contains(
            "path: RestProcedureMetadata(method: 'GET', path: '/users/:userId'),",
          ),
        );
        expect(
          generatedOutput,
          contains(
            "description: 'Resolve a user by id from a shared contract.'",
          ),
        );
        expect(
          generatedOutput,
          contains("rawInput['id'] = decodeRestScalarParameter<String>("),
        );
        expect(
          generatedOutput,
          contains("rawValue: pathParameters['userId'],"),
        );
        expect(
          generatedOutput,
          contains("rawInput['include'] = decodeRestScalarParameter<String?>("),
        );
        expect(
          generatedOutput,
          contains("rawValue: request.queryParameters['view'],"),
        );
        expect(
          generatedOutput,
          contains(
            "rawInput['tenantId'] = decodeRestScalarParameter<String?>(",
          ),
        );
        expect(
          generatedOutput,
          contains("lookupRestHeader(request.headers, 'x-tenant-id')"),
        );
        expect(
          generatedOutput,
          contains('final input = ((rawInput) => GetUserDto.fromJson('),
        );
        expect(
          generatedOutput,
          contains('context: \'RPC method "user.getById" input\','),
        );
        expect(
          generatedOutput,
          contains('container.userController.getById(context, input)'),
        );
        expect(generatedOutput, contains("parameterName: 'include',"));
        expect(
          generatedOutput,
          contains('source: ProcedureParameterSourceKind.query,'),
        );
        expect(generatedOutput, contains("wireName: 'view',"));
        expect(generatedOutput, contains("parameterName: 'tenantId',"));
        expect(
          generatedOutput,
          contains('source: ProcedureParameterSourceKind.header,'),
        );
        expect(generatedOutput, contains("wireName: 'x-tenant-id',"));
      },
    );

    test(
      'When a REST-enabled method uses @RpcInput(binding: ...) field refs for a POST route then it emits path, header, and body merging code',
      () async {
        final run = await runModuleBuilder(_sharedRpcAndRestBodySource);

        expect(run.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains(
            "path: RestProcedureMetadata(method: 'POST', path: '/users/:userId'),",
          ),
        );
        expect(
          generatedOutput,
          contains('final rawInput = request.body.trim().isEmpty'),
        );
        expect(generatedOutput, contains("decodeRestBody<JsonObject>("));
        expect(
          generatedOutput,
          contains("rawInput['id'] = decodeRestScalarParameter<String>("),
        );
        expect(
          generatedOutput,
          contains("rawValue: pathParameters['userId'],"),
        );
        expect(
          generatedOutput,
          contains(
            "rawInput['tenantId'] = decodeRestScalarParameter<String?>(",
          ),
        );
        expect(
          generatedOutput,
          contains("lookupRestHeader(request.headers, 'x-tenant-id')"),
        );
        expect(generatedOutput, contains("parameterName: 'input',"));
        expect(
          generatedOutput,
          contains('source: ProcedureParameterSourceKind.body,'),
        );
      },
    );

    test(
      'When a module imports another module and consumes its exported provider then the builder emits a flattened app graph',
      () async {
        final run = await runModuleBuilder(_nestedModuleSource);

        expect(run.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains('final userController = UserController(userService);'),
        );
        expect(
          generatedOutput,
          contains('final adminController = AdminController(userService);'),
        );
        expect(
          generatedOutput,
          contains(
            'final userModuleRuntime = dartOrpcCreateUserModuleRuntime();',
          ),
        );
        expect(
          generatedOutput,
          contains('...userModuleRuntime.procedures.procedures,'),
        );
        expect(
          generatedOutput,
          contains('...userModuleRuntime.restRoutes.routes,'),
        );
        expect(
          generatedOutput,
          contains('container.userController.getById(context, input)'),
        );
        expect(
          generatedOutput,
          contains('container.adminController.lookup(context, input)'),
        );
        expect(generatedOutput, contains("method: 'user.getById',"));
        expect(generatedOutput, contains("method: 'admin.lookup',"));
        expect(
          generatedOutput,
          contains('late final user = UserClient(_transports);'),
        );
        expect(
          generatedOutput,
          contains('late final admin = AdminClient(_transports);'),
        );
      },
    );

    test(
      'When a module re-exports an imported module then downstream modules can resolve its providers',
      () async {
        final run = await runModuleBuilder(_reExportedModuleSource);

        expect(run.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains('final adminController = AdminController(userService);'),
        );
        expect(generatedOutput, contains("method: 'admin.lookup',"));
      },
    );

    test(
      'When a module imports another module through an intermediate module then composed client getters avoid transitive type references',
      () async {
        final run = await runModuleBuilder(_transitiveClientCompositionSource);

        expect(run.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains(
            'late final ApiClient _apiModuleClient = ApiClient(transports: _transports);',
          ),
        );
        expect(
          generatedOutput,
          contains('late final user = _apiModuleClient.user;'),
        );
        expect(
          generatedOutput,
          isNot(
            contains('late final UserClient user = _apiModuleClient.user;'),
          ),
        );
      },
    );

    test(
      'When a module imports another module from a separate library then the generated module library re-exports the child generated library',
      () async {
        final run = await runModuleBuilder(
          _importingModuleSource,
          additionalSources: {'lib/api_module.dart': _importedApiModuleSource},
        );

        expect(run.succeeded, isTrue);
        expect(
          run.generatedOutput,
          contains("export 'package:a/api_module.orpc.dart';"),
        );
      },
    );

    test(
      'When provider dependencies cannot be resolved then the builder reports a generation error',
      () async {
        final run = await runModuleBuilder(_missingProviderDependencySource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'Unable to resolve provider constructor dependencies for: UserService.',
          ),
        );
      },
    );

    test(
      'When a guard is declared but not registered as a provider then generation fails',
      () async {
        final run = await runModuleBuilder(_missingGuardProviderSource);

        expect(run.succeeded, isFalse);
        expect(run.errors.join('\n'), contains('guard "AuthGuard"'));
        expect(
          run.errors.join('\n'),
          contains('not available as a module provider'),
        );
      },
    );

    test(
      'When a module import entry is not annotated with Module then generation fails',
      () async {
        final run = await runModuleBuilder(_invalidImportedModuleSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            '@Module.imports entries must be classes annotated with @Module.',
          ),
        );
      },
    );

    test(
      'When a module exports a provider that is not local or imported then generation fails',
      () async {
        final run = await runModuleBuilder(_unknownExportSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'Module "AppModule" may only export its own providers or providers/modules from @Module.imports. Unknown export "UserService".',
          ),
        );
      },
    );

    test('When module imports are circular then generation fails', () async {
      final run = await runModuleBuilder(_circularModuleImportsSource);

      expect(run.succeeded, isFalse);
      expect(
        run.errors.join('\n'),
        contains(
          'Detected circular @Module.imports chain: AppModule -> UserModule -> AppModule.',
        ),
      );
    });

    test(
      'When a REST-enabled method mixes @RpcInput with explicit REST source parameters then generation fails',
      () async {
        final run = await runModuleBuilder(_mixedRpcInputAndRestParamsSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'RPC method "getById" may not mix @RpcInput with @PathParam, @QueryParam, or @Body.',
          ),
        );
      },
    );

    test(
      'When a REST-enabled method declares more than one body parameter then generation fails',
      () async {
        final run = await runModuleBuilder(_multipleBodyParametersSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'RPC method "updateUser" may declare at most one @Body parameter.',
          ),
        );
      },
    );

    test(
      'When a REST-enabled method is missing a path placeholder binding then generation fails',
      () async {
        final run = await runModuleBuilder(_missingPathBindingSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'RPC method "getById" must declare @PathParam bindings for route "/users/:id": id.',
          ),
        );
      },
    );

    test(
      'When a REST-enabled method binds a path parameter not present in the route then generation fails',
      () async {
        final run = await runModuleBuilder(_unknownPathBindingSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'RPC method "getById" declares @PathParam bindings not present in route "/users/:id": slug.',
          ),
        );
      },
    );

    test(
      'When a method uses REST source annotations without a REST mapping then generation fails',
      () async {
        final run = await runModuleBuilder(_restSourceWithoutRestMappingSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'RPC method "getById" may only use @PathParam, @QueryParam, or @Body when RpcMethod(path: ...) is declared.',
          ),
        );
      },
    );

    test(
      'When a method declares duplicate query parameter wire names then generation fails',
      () async {
        final run = await runModuleBuilder(_duplicateQueryWireNamesSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'RPC method "search" declares duplicate @QueryParam wire name "include".',
          ),
        );
      },
    );

    test(
      'When a method returns a typed stream then the builder emits one streaming contract for RPC, SSE, OpenAPI, and the client',
      () async {
        final run = await runModuleBuilder(_validStreamingModuleSource);

        expect(run.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains('RpcStreamProcedure<WatchInput, MessageDto>('),
        );
        expect(
          generatedOutput,
          contains('kind: RpcProcedureKind.serverStream,'),
        );
        expect(generatedOutput, contains('RestStreamRoute('));
        expect(
          generatedOutput,
          contains('responseKind: RestResponseKind.sse,'),
        );
        expect(
          generatedOutput,
          contains("rawValue: pathParameters['channelId'],"),
        );
        expect(
          generatedOutput,
          contains("rawValue: request.queryParameters['after'],"),
        );
        expect(
          generatedOutput,
          contains("lookupRestHeader(request.headers, 'x-tenant-id')"),
        );
        expect(
          generatedOutput,
          contains('Stream<MessageDto> watchMessages(WatchInput input) {'),
        );
        expect(
          generatedOutput,
          contains("_transports.requireStreaming('chat.watchMessages')"),
        );
      },
    );

    test(
      'When a unary method declares an SSE mapping then generation fails',
      () async {
        final run = await runModuleBuilder(_unarySseModuleSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains('Unary RPC method "watch" may not use RestMapping.sse.'),
        );
      },
    );

    test(
      'When a streaming method declares a JSON REST mapping then generation fails',
      () async {
        final run = await runModuleBuilder(_streamJsonRestModuleSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains(
            'Streaming RPC method "watch" must use RestMapping.sse when a REST mapping is declared.',
          ),
        );
      },
    );

    test('When a method future-wraps a stream then generation fails', () async {
      final run = await runModuleBuilder(_futureStreamModuleSource);

      expect(run.succeeded, isFalse);
      expect(
        run.errors.join('\n'),
        contains(
          'RPC method "watch" must return Stream<T> directly, not Future<Stream<T>>.',
        ),
      );
    });

    for (final scenario in <(String, String, String)>[
      (
        'raw Stream',
        'Stream',
        'must return a non-nullable Stream<T> with one event type',
      ),
      (
        'nullable Stream',
        'Stream<MessageDto>?',
        'must return a non-nullable Stream<T> with one event type',
      ),
      (
        'nested Stream',
        'Stream<Stream<MessageDto>>',
        'may not return a nested Stream<Stream<T>>',
      ),
    ]) {
      test(
        'When a method returns ${scenario.$1} then generation fails',
        () async {
          final run = await runModuleBuilder(
            _streamShapeModuleSource.replaceFirst('RETURN_TYPE', scenario.$2),
          );

          expect(run.succeeded, isFalse);
          expect(run.errors.join('\n'), contains(scenario.$3));
        },
      );
    }

    test(
      'When a stream returns scalar events then generation uses identity codecs',
      () async {
        final run = await runModuleBuilder(
          _streamShapeModuleSource.replaceFirst(
            'RETURN_TYPE',
            'Stream<String>',
          ),
        );

        expect(run.succeeded, isTrue);
        expect(
          run.generatedOutput,
          contains('RpcStreamProcedure<Null, String>('),
        );
        expect(
          run.generatedOutput,
          contains('decode: (json) => json as String'),
        );
      },
    );

    test(
      'When a typed stream omits REST mapping then it remains WebSocket-only',
      () async {
        final run = await runModuleBuilder(
          _streamShapeModuleSource.replaceFirst(
            'RETURN_TYPE',
            'Stream<MessageDto>',
          ),
        );

        expect(run.succeeded, isTrue);
        expect(
          run.generatedOutput,
          contains('RpcStreamProcedure<Null, MessageDto>('),
        );
        expect(run.generatedOutput, contains('Stream<MessageDto> watch() {'));
        expect(run.generatedOutput, isNot(contains('RestStreamRoute(')));
      },
    );

    test(
      'Given a stream DTO inherits its codec when generation runs then it is supported',
      () async {
        final run = await runModuleBuilder(_inheritedStreamCodecModuleSource);

        expect(run.succeeded, isTrue);
        expect(
          run.generatedOutput,
          contains('RpcStreamProcedure<Null, MessageDto>('),
        );
      },
    );

    test(
      'When an SSE stream binds a request body then generation fails',
      () async {
        final run = await runModuleBuilder(_sseBodyBindingModuleSource);

        expect(run.succeeded, isFalse);
        expect(
          run.errors.join('\n'),
          contains('may not bind @RpcInput(binding: ...) body fields'),
        );
      },
    );
  });
}

const _validStreamingModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [ChatController])
final class AppModule {
  const AppModule();
}

@Controller('chat')
final class ChatController {
  @RpcMethod(
    name: 'watchMessages',
    path: RestMapping.sse('/channels/:channelId/messages'),
  )
  Stream<MessageDto> watchMessages(
    RpcContext context,
    @RpcInput(
      binding: RpcInputBinding(
        path: [RpcInputField(WatchInputFields.channelId)],
        query: [RpcInputField(WatchInputFields.after)],
        headers: [
          RpcInputField(WatchInputFields.tenantId, 'x-tenant-id'),
        ],
      ),
    )
    WatchInput input,
  ) async* {
    yield MessageDto(id: input.channelId, text: input.after ?? 'first');
  }
}

final class WatchInputFields {
  const WatchInputFields._();

  static const channelId = 'channelId';
  static const after = 'after';
  static const tenantId = 'tenantId';
}

final class WatchInput {
  const WatchInput({
    required this.channelId,
    required this.after,
    required this.tenantId,
  });

  factory WatchInput.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'WatchInput');
    return WatchInput(
      channelId: expectStringField(object, 'channelId'),
      after: optionalStringField(object, 'after'),
      tenantId: optionalStringField(object, 'tenantId'),
    );
  }

  final String channelId;
  final String? after;
  final String? tenantId;

  JsonObject toJson() => {
    'channelId': channelId,
    'after': after,
    'tenantId': tenantId,
  };
}

final class MessageDto {
  const MessageDto({required this.id, required this.text});

  factory MessageDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'MessageDto');
    return MessageDto(
      id: expectStringField(object, 'id'),
      text: expectStringField(object, 'text'),
    );
  }

  final String id;
  final String text;

  JsonObject toJson() => {'id': id, 'text': text};
}
''';

const _unarySseModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [EventsController])
final class AppModule {
  const AppModule();
}

@Controller('events')
final class EventsController {
  @RpcMethod(path: RestMapping.sse('/events'))
  Future<void> watch() async {}
}
''';

const _scalarAndVoidOutputModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [StatusController])
final class AppModule {
  const AppModule();
}

@Controller('status')
final class StatusController {
  @RpcMethod(path: RestMapping.get('/greeting'))
  String greeting() => 'hello';

  @RpcMethod(path: RestMapping.delete('/status'))
  void clear() {}

  @RpcMethod()
  Future<void> clearLater() async {}
}
''';

const _streamJsonRestModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [EventsController])
final class AppModule {
  const AppModule();
}

@Controller('events')
final class EventsController {
  @RpcMethod(path: RestMapping.get('/events'))
  Stream<String> watch() => const Stream.empty();
}
''';

const _futureStreamModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [EventsController])
final class AppModule {
  const AppModule();
}

@Controller('events')
final class EventsController {
  @RpcMethod()
  Future<Stream<String>> watch() async => const Stream.empty();
}
''';

const _streamShapeModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [EventsController])
final class AppModule {
  const AppModule();
}

@Controller('events')
final class EventsController {
  @RpcMethod()
  RETURN_TYPE watch() => throw UnimplementedError();
}

final class MessageDto {
  const MessageDto();

  factory MessageDto.fromJson(Object? json) => const MessageDto();

  Map<String, Object?> toJson() => const {};
}
''';

const _inheritedStreamCodecModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [EventsController])
final class AppModule {
  const AppModule();
}

@Controller('events')
final class EventsController {
  @RpcMethod()
  Stream<MessageDto> watch() => const Stream.empty();
}

mixin GeneratedJsonCodec {
  Map<String, Object?> toJson() => const {};
}

final class MessageDto with GeneratedJsonCodec {
  const MessageDto();

  factory MessageDto.fromJson(Object? json) => const MessageDto();
}
''';

const _sseBodyBindingModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [EventsController])
final class AppModule {
  const AppModule();
}

@Controller('events')
final class EventsController {
  @RpcMethod(path: RestMapping.sse('/events'))
  Stream<MessageDto> watch(
    @RpcInput(
      binding: RpcInputBinding(
        body: [RpcInputField('filter')],
      ),
    )
    WatchInput input,
  ) => const Stream.empty();
}

final class WatchInput {
  const WatchInput({required this.filter});

  factory WatchInput.fromJson(Object? json) => const WatchInput(filter: '');

  final String filter;

  Map<String, Object?> toJson() => {'filter': filter};
}

final class MessageDto {
  const MessageDto();

  factory MessageDto.fromJson(Object? json) => const MessageDto();

  Map<String, Object?> toJson() => const {};
}
''';

const _validRpcModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [UserController], providers: [UserService])
final class AppModule {
  const AppModule();
}

final class UserService {
  UserResponseDto getById(String id) => UserResponseDto(id: id, name: 'Ada');
}

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'getById')
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }

  @RpcMethod(name: 'status')
  UserStatusDto status() {
    return const UserStatusDto(status: 'ready');
  }
}

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
    );
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}

final class UserStatusDto {
  const UserStatusDto({required this.status});

  factory UserStatusDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserStatusDto');
    return UserStatusDto(
      status: expectStringField(object, 'status', nonEmpty: true),
    );
  }

  final String status;

  JsonObject toJson() => {'status': status};
}
''';

const _guardedRpcModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(
  controllers: [UserController],
  providers: [UserService, AuthGuard, UserReadGuard],
)
final class AppModule {
  const AppModule();
}

final class UserService {
  UserResponseDto getById(String id) => UserResponseDto(id: id, name: 'Ada');
}

final class AuthGuard implements RpcGuard {
  @override
  Future<void> canActivate(RpcGuardContext context) async {}
}

final class UserReadGuard implements RpcGuard {
  UserReadGuard(this.userService);

  final UserService userService;

  @override
  Future<void> canActivate(RpcGuardContext context) async {
    userService.getById('guard');
  }
}

@RpcMetadata('permissions')
final class RequirePermissions {
  const RequirePermissions({this.anyOf, this.allOf})
    : assert((anyOf == null) != (allOf == null));

  final List<String>? anyOf;
  final List<String>? allOf;
}

@UseGuards([AuthGuard])
@RequirePermissions(allOf: ['tenant.active'])
@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @UseGuards([UserReadGuard])
  @RequirePermissions(anyOf: ['user.read', 'user.admin'])
  @RpcMethod(name: 'getById', path: RestMapping.get('/users/:id'))
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
    );
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _missingGuardProviderSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [UserController], providers: [UserService])
final class AppModule {
  const AppModule();
}

final class UserService {}

final class AuthGuard implements RpcGuard {
  @override
  Future<void> canActivate(RpcGuardContext context) async {}
}

@UseGuards([AuthGuard])
@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'status')
  JsonObject status() => {'ready': true};
}
''';

const _validRestMetadataSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [UserController], providers: [UserService])
final class AppModule {
  const AppModule();
}

final class UserService {
  UserResponseDto getById(String id) => UserResponseDto(id: id, name: 'Ada');
}

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'getById')
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }

  @RpcMethod(
    name: 'findBySlug',
    path: RestMapping.get('/users/:id'),
    description: 'Find a user by route-bound id.',
    tags: ['user', 'lookup'],
  )
  Future<UserResponseDto> findBySlug(
    RpcContext context,
    @PathParam() String id,
    @QueryParam('include') String view,
  ) async {
    return userService.getById(id);
  }
}

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
    );
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _splitContractModuleSource = r'''
library example;

import 'package:a/contracts.dart';
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [UserController], providers: [UserService])
final class AppModule {
  const AppModule();
}

final class UserService {
  UserResponseDto getById(String id) => UserResponseDto(id: id, name: 'Ada');
}

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'getById')
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}
''';

const _splitContractDtoSource = r'''
library contracts;

import 'package:dart_orpc_core/dart_orpc_core.dart';

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
    );
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _sharedRpcAndRestGetSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [UserController], providers: [UserService])
final class AppModule {
  const AppModule();
}

final class UserService {
  UserResponseDto getById(String id, {String? include, String? tenantId}) =>
      UserResponseDto(
        id: id,
        name: tenantId == 'compact-tenant'
            ? 'Scoped Ada'
            : include == 'compact'
            ? 'Ada'
            : 'Ada Lovelace',
      );
}

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(
    name: 'getById',
    path: RestMapping.get('/users/:userId'),
    description: 'Resolve a user by id from a shared contract.',
    tags: ['user'],
  )
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(
      input.id,
      include: input.include,
      tenantId: input.tenantId,
    );
  }
}

final class GetUserDto {
  const GetUserDto({required this.id, this.include, this.tenantId});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      include: object['include'] as String?,
      tenantId: object['tenantId'] as String?,
    );
  }

  @FromPath('userId')
  final String id;
  @FromQuery('view')
  final String? include;
  @FromHeader('x-tenant-id')
  final String? tenantId;

  JsonObject toJson() {
    final json = <String, Object?>{'id': id};
    if (include != null) {
      json['include'] = include;
    }
    if (tenantId != null) {
      json['tenantId'] = tenantId;
    }
    return json;
  }
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _sharedRpcAndRestBodySource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [UserController], providers: [UserService])
final class AppModule {
  const AppModule();
}

final class UserService {
  UserResponseDto updateUser(UpdateUserDto input) => UserResponseDto(
        id: input.id,
        name: input.tenantId == null ? input.name : '${input.name} (${input.tenantId})',
      );
}

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(
    name: 'update',
    path: RestMapping.post('/users/:userId'),
  )
  Future<UserResponseDto> update(
    RpcContext context,
    @RpcInput(
      binding: RpcInputBinding<UpdateUserDto>(
        path: [RpcInputField('id', 'userId')],
        headers: [RpcInputField('tenantId', 'x-tenant-id')],
        body: [UpdateUserDtoFields.name],
      ),
    )
    UpdateUserDto input,
  ) async {
    return userService.updateUser(input);
  }
}

final class UpdateUserDto {
  const UpdateUserDto({required this.id, required this.name, this.tenantId});

  factory UpdateUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UpdateUserDto');
    return UpdateUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
      tenantId: object['tenantId'] as String?,
    );
  }

  final String id;
  final String name;
  final String? tenantId;

  JsonObject toJson() {
    final json = <String, Object?>{'id': id, 'name': name};
    if (tenantId != null) {
      json['tenantId'] = tenantId;
    }
    return json;
  }
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _nestedModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(imports: [UserModule], controllers: [AdminController])
final class AppModule {
  const AppModule();
}

@Module(
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
)
final class UserModule {
  const UserModule();
}

final class UserService {
  UserResponseDto getById(String id) => UserResponseDto(id: id, name: 'Ada');
}

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'getById')
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}

@Controller('admin')
final class AdminController {
  AdminController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'lookup')
  Future<UserResponseDto> lookup(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
    );
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _reExportedModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(imports: [ApiModule], controllers: [AdminController])
final class AppModule {
  const AppModule();
}

@Module(imports: [UserModule], exports: [UserModule])
final class ApiModule {
  const ApiModule();
}

@Module(providers: [UserService], exports: [UserService])
final class UserModule {
  const UserModule();
}

final class UserService {
  UserResponseDto getById(String id) => UserResponseDto(id: id, name: 'Ada');
}

@Controller('admin')
final class AdminController {
  AdminController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'lookup')
  Future<UserResponseDto> lookup(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
    );
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _importingModuleSource = r'''
library example;

import 'api_module.dart';
import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(imports: [ApiModule])
final class AppModule {
  const AppModule();
}
''';

const _importedApiModuleSource = r'''
library api_module;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

@Module(controllers: [UserController], providers: [UserService])
final class ApiModule {
  const ApiModule();
}

final class UserService {
  UserResponseDto getById(String id) => UserResponseDto(id: id, name: 'Ada');
}

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'getById')
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
    );
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _missingProviderDependencySource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(providers: [UserService])
final class AppModule {
  const AppModule();
}

final class MissingDependency {}

final class UserService {
  UserService(this.dependency);

  final MissingDependency dependency;
}
''';

const _transitiveClientCompositionSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(imports: [ApiModule])
final class AppModule {
  const AppModule();
}

@Module(imports: [UserModule])
final class ApiModule {
  const ApiModule();
}

@Module(
  controllers: [UserController],
  providers: [UserService],
  exports: [UserService],
)
final class UserModule {
  const UserModule();
}

final class UserService {
  UserResponseDto getById(String id) => UserResponseDto(id: id, name: 'Ada');
}

@Controller('user')
final class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(name: 'getById')
  Future<UserResponseDto> getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(
      id: expectStringField(object, 'id', nonEmpty: true),
    );
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id, required this.name});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(
      id: expectStringField(object, 'id', nonEmpty: true),
      name: expectStringField(object, 'name', nonEmpty: true),
    );
  }

  final String id;
  final String name;

  JsonObject toJson() => {'id': id, 'name': name};
}
''';

const _invalidImportedModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(imports: [NotAModule])
final class AppModule {
  const AppModule();
}

final class NotAModule {
  const NotAModule();
}
''';

const _unknownExportSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(exports: [UserService])
final class AppModule {
  const AppModule();
}

final class UserService {
  const UserService();
}
''';

const _circularModuleImportsSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(imports: [UserModule])
final class AppModule {
  const AppModule();
}

@Module(imports: [AppModule])
final class UserModule {
  const UserModule();
}
''';

const _mixedRpcInputAndRestParamsSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [UserController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class UserController {
  @RpcMethod(path: RestMapping.get('/users/:id'))
  UserResponseDto getById(
    RpcContext context,
    @RpcInput() GetUserDto input,
    @PathParam() String id,
  ) {
    return UserResponseDto(id: id);
  }
}

final class GetUserDto {
  const GetUserDto({required this.id});

  factory GetUserDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'GetUserDto');
    return GetUserDto(id: expectStringField(object, 'id'));
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class UserResponseDto {
  const UserResponseDto({required this.id});

  factory UserResponseDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'UserResponseDto');
    return UserResponseDto(id: expectStringField(object, 'id'));
  }

  final String id;

  JsonObject toJson() => {'id': id};
}
''';

const _multipleBodyParametersSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [UserController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class UserController {
  @RpcMethod(path: RestMapping.post('/users'))
  void updateUser(
    @Body() UpdateUserDto body,
    @Body() AuditDto audit,
  ) {}
}

final class UpdateUserDto {
  const UpdateUserDto();
}

final class AuditDto {
  const AuditDto();
}
''';

const _missingPathBindingSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [UserController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class UserController {
  @RpcMethod(path: RestMapping.get('/users/:id'))
  void getById(@QueryParam() String filter) {}
}
''';

const _unknownPathBindingSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [UserController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class UserController {
  @RpcMethod(path: RestMapping.get('/users/:id'))
  void getById(@PathParam('slug') String id) {}
}
''';

const _restSourceWithoutRestMappingSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [UserController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class UserController {
  @RpcMethod()
  void getById(@PathParam() String id) {}
}
''';

const _duplicateQueryWireNamesSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [UserController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class UserController {
  @RpcMethod(path: RestMapping.get('/users'))
  void search(
    @QueryParam('include') String first,
    @QueryParam('include') String second,
  ) {}
}
''';

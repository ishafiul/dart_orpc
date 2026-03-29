import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_orpc_generator/dart_orpc_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Given RpcModuleGenerator', () {
    test(
      'When the builder runs for a valid module then it emits registry, metadata, app, and client code',
      () async {
        final run = await _runBuilder(_validRpcModuleSource);

        expect(run.result.succeeded, isTrue);
        expect(
          run.result.outputs,
          contains(AssetId('a', 'lib/example.orpc.dart')),
        );

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
        expect(generatedOutput, contains('RpcProcedure<Null, UserStatusDto>('));
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
          contains('procedures: _\$createAppModuleProcedureRegistry()'),
        );
        expect(
          generatedOutput,
          contains('restRoutes: _\$createAppModuleRestRouteRegistry()'),
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
          _countMatches(generatedOutput, 'final userService = UserService();'),
          1,
        );
        expect(
          _countMatches(
            generatedOutput,
            'final userController = UserController(userService);',
          ),
          1,
        );
        expect(generatedOutput, contains('class AppClient {'));
        expect(
          generatedOutput,
          contains('late final user = UserClient(_caller);'),
        );
        expect(generatedOutput, contains('Future<UserStatusDto> status() {'));
      },
    );

    test(
      'When client DTOs live in a separate contract library then the generated module library re-exports that contract library',
      () async {
        final run = await _runBuilder(
          _splitContractModuleSource,
          additionalSources: {'lib/contracts.dart': _splitContractDtoSource},
        );

        expect(run.result.succeeded, isTrue);
        expect(
          run.generatedOutput,
          contains("export 'package:a/contracts.dart';"),
        );
      },
    );

    test(
      'When controller and method guards are declared then the generated module resolves guard providers and runs them for both RPC and REST',
      () async {
        final run = await _runBuilder(_guardedRpcModuleSource);

        expect(run.result.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(generatedOutput, contains('final authGuard = AuthGuard();'));
        expect(
          generatedOutput,
          contains('final userReadGuard = UserReadGuard(userService);'),
        );
        expect(
          generatedOutput,
          contains('beforeInvoke: (context, input) => runRpcGuards('),
        );
        expect(
          generatedOutput,
          contains("procedure: metadataRegistry['user.getById']!,"),
        );
        expect(
          generatedOutput,
          contains('[container.authGuard, container.userReadGuard],'),
        );
        expect(generatedOutput, contains('await runRpcGuards('));
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
        final run = await _runBuilder(_validRestMetadataSource);

        expect(run.result.succeeded, isTrue);

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
          contains('RpcProcedure<GetUserDto, UserResponseDto>('),
        );
      },
    );

    test(
      'When a REST-enabled method uses DTO field source annotations then it emits shared path, query, and header bindings from the same procedure',
      () async {
        final run = await _runBuilder(_sharedRpcAndRestGetSource);

        expect(run.result.succeeded, isTrue);

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
        final run = await _runBuilder(_sharedRpcAndRestBodySource);

        expect(run.result.succeeded, isTrue);

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
        final run = await _runBuilder(_nestedModuleSource);

        expect(run.result.succeeded, isTrue);

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
          contains('late final user = UserClient(_caller);'),
        );
        expect(
          generatedOutput,
          contains('late final admin = AdminClient(_caller);'),
        );
      },
    );

    test(
      'When a module re-exports an imported module then downstream modules can resolve its providers',
      () async {
        final run = await _runBuilder(_reExportedModuleSource);

        expect(run.result.succeeded, isTrue);

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
        final run = await _runBuilder(_transitiveClientCompositionSource);

        expect(run.result.succeeded, isTrue);

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains(
            'late final ApiClient _apiModuleClient = ApiClient(transport: _transport);',
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
        final run = await _runBuilder(
          _importingModuleSource,
          additionalSources: {'lib/api_module.dart': _importedApiModuleSource},
        );

        expect(run.result.succeeded, isTrue);
        expect(
          run.generatedOutput,
          contains("export 'package:a/api_module.orpc.dart';"),
        );
      },
    );

    test(
      'When provider dependencies cannot be resolved then the builder reports a generation error',
      () async {
        final run = await _runBuilder(_missingProviderDependencySource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            'Unable to resolve provider constructor dependencies for: UserService.',
          ),
        );
      },
    );

    test(
      'When a guard is declared but not registered as a provider then generation fails',
      () async {
        final run = await _runBuilder(_missingGuardProviderSource);

        expect(run.result.succeeded, isFalse);
        expect(run.result.errors.join('\n'), contains('guard "AuthGuard"'));
        expect(
          run.result.errors.join('\n'),
          contains('not available as a module provider'),
        );
      },
    );

    test(
      'When a module import entry is not annotated with Module then generation fails',
      () async {
        final run = await _runBuilder(_invalidImportedModuleSource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            '@Module.imports entries must be classes annotated with @Module.',
          ),
        );
      },
    );

    test(
      'When a module exports a provider that is not local or imported then generation fails',
      () async {
        final run = await _runBuilder(_unknownExportSource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            'Module "AppModule" may only export its own providers or providers/modules from @Module.imports. Unknown export "UserService".',
          ),
        );
      },
    );

    test('When module imports are circular then generation fails', () async {
      final run = await _runBuilder(_circularModuleImportsSource);

      expect(run.result.succeeded, isFalse);
      expect(
        run.result.errors.join('\n'),
        contains(
          'Detected circular @Module.imports chain: AppModule -> UserModule -> AppModule.',
        ),
      );
    });

    test(
      'When a REST-enabled method mixes @RpcInput with explicit REST source parameters then generation fails',
      () async {
        final run = await _runBuilder(_mixedRpcInputAndRestParamsSource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            'RPC method "getById" may not mix @RpcInput with @PathParam, @QueryParam, or @Body.',
          ),
        );
      },
    );

    test(
      'When a REST-enabled method declares more than one body parameter then generation fails',
      () async {
        final run = await _runBuilder(_multipleBodyParametersSource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            'RPC method "updateUser" may declare at most one @Body parameter.',
          ),
        );
      },
    );

    test(
      'When a REST-enabled method is missing a path placeholder binding then generation fails',
      () async {
        final run = await _runBuilder(_missingPathBindingSource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            'RPC method "getById" must declare @PathParam bindings for route "/users/:id": id.',
          ),
        );
      },
    );

    test(
      'When a REST-enabled method binds a path parameter not present in the route then generation fails',
      () async {
        final run = await _runBuilder(_unknownPathBindingSource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            'RPC method "getById" declares @PathParam bindings not present in route "/users/:id": slug.',
          ),
        );
      },
    );

    test(
      'When a method uses REST source annotations without a REST mapping then generation fails',
      () async {
        final run = await _runBuilder(_restSourceWithoutRestMappingSource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            'RPC method "getById" may only use @PathParam, @QueryParam, or @Body when RpcMethod(path: ...) is declared.',
          ),
        );
      },
    );

    test(
      'When a method declares duplicate query parameter wire names then generation fails',
      () async {
        final run = await _runBuilder(_duplicateQueryWireNamesSource);

        expect(run.result.succeeded, isFalse);
        expect(
          run.result.errors.join('\n'),
          contains(
            'RPC method "search" declares duplicate @QueryParam wire name "include".',
          ),
        );
      },
    );
  });
}

Future<_BuilderRun> _runBuilder(
  String source, {
  Map<String, String> additionalSources = const {},
}) async {
  final readerWriter = TestReaderWriter(rootPackage: 'a');
  await readerWriter.testing.loadIsolateSources();

  final sources = <String, String>{
    'a|lib/example.dart': source,
    for (final entry in additionalSources.entries)
      'a|${entry.key}': entry.value,
  };

  final partResult = await testBuilder(
    dartOrpcBuilder(BuilderOptions(const {})),
    sources,
    rootPackage: 'a',
    readerWriter: readerWriter,
    generateFor: {'a|lib/example.dart'},
  );

  final generatedPartAsset = AssetId(
    'a',
    '.dart_tool/build/generated/a/lib/example.dart_orpc.g.part',
  );
  if (readerWriter.testing.exists(generatedPartAsset)) {
    readerWriter.testing.writeString(AssetId('a', 'lib/example.g.dart'), '''
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'example.dart';

${readerWriter.testing.readString(generatedPartAsset)}
''');
  }

  final moduleResult = await testBuilder(
    dartOrpcModuleBuilder(BuilderOptions(const {})),
    sources,
    rootPackage: 'a',
    readerWriter: readerWriter,
    generateFor: {'a|lib/example.dart'},
  );

  return _BuilderRun(
    readerWriter: readerWriter,
    result: _CombinedBuilderResult(
      partResult: partResult,
      moduleResult: moduleResult,
    ),
  );
}

final class _BuilderRun {
  const _BuilderRun({required this.readerWriter, required this.result});

  final TestReaderWriter readerWriter;
  final _CombinedBuilderResult result;

  String get generatedOutput {
    final outputAsset = readerWriter.testing.assets.firstWhere(
      (asset) => asset.path.endsWith('example.orpc.dart'),
    );
    return readerWriter.testing.readString(outputAsset);
  }
}

final class _CombinedBuilderResult {
  const _CombinedBuilderResult({
    required this.partResult,
    required this.moduleResult,
  });

  final dynamic partResult;
  final dynamic moduleResult;

  bool get succeeded => partResult.succeeded && moduleResult.succeeded;

  List<dynamic> get outputs => [...partResult.outputs, ...moduleResult.outputs];

  List<dynamic> get errors => [...partResult.errors, ...moduleResult.errors];
}

int _countMatches(String value, String pattern) {
  return RegExp(RegExp.escape(pattern)).allMatches(value).length;
}

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

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
          contains(AssetId('a', 'lib/example.dart_orpc.g.part')),
        );

        final generatedOutput = run.generatedOutput;
        expect(
          generatedOutput,
          contains(
            'RpcProcedureRegistry _\$createAppModuleProcedureRegistry() {',
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
          contains('abstract final class GetUserDtoFields {'),
        );
        expect(
          generatedOutput,
          contains(
            'OpenApiSchemaRegistry _\$createAppModuleOpenApiSchemaRegistry() {',
          ),
        );
        expect(
          generatedOutput,
          contains('JsonObject _\$createAppModuleOpenApiDocument() {'),
        );
        expect(
          generatedOutput,
          contains('RestRouteRegistry _\$createAppModuleRestRouteRegistry() {'),
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
          contains('RpcHttpApp _\$buildAppModuleRpcApp() {'),
        );
        expect(
          generatedOutput,
          contains('restRoutes: _\$createAppModuleRestRouteRegistry()'),
        );
        expect(
          generatedOutput,
          contains('openApiDocument: _\$createAppModuleOpenApiDocument()'),
        );
        expect(
          generatedOutput,
          contains("docsHtml: createScalarHtml(title: 'App API')"),
        );
        expect(generatedOutput, contains('class AppClient {'));
        expect(
          generatedOutput,
          contains('late final UserClient user = UserClient(_caller);'),
        );
        expect(generatedOutput, contains('Future<UserStatusDto> status() {'));
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
          contains('JsonObject _\$createAppModuleOpenApiDocument() {'),
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
          contains(
            'handler: (context, input) => userController.getById(context, input),',
          ),
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

Future<_BuilderRun> _runBuilder(String source) async {
  final readerWriter = TestReaderWriter(rootPackage: 'a');
  await readerWriter.testing.loadIsolateSources();

  final result = await testBuilder(
    dartOrpcBuilder(BuilderOptions(const {})),
    {'a|lib/example.dart': source},
    rootPackage: 'a',
    readerWriter: readerWriter,
  );

  return _BuilderRun(readerWriter: readerWriter, result: result);
}

final class _BuilderRun {
  const _BuilderRun({required this.readerWriter, required this.result});

  final TestReaderWriter readerWriter;
  final dynamic result;

  String get generatedOutput {
    return readerWriter.testing.readString(
      AssetId('a', '.dart_tool/build/generated/a/lib/example.dart_orpc.g.part'),
    );
  }
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

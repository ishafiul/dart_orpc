import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_orpc_generator/dart_orpc_generator.dart';
import 'package:test/test.dart';

void main() {
  group('Given RpcModuleGenerator', () {
    test(
      'When the builder runs for a valid module then it emits registry, app, and client code',
      () async {
        final readerWriter = TestReaderWriter(rootPackage: 'a');
        await readerWriter.testing.loadIsolateSources();

        final result = await testBuilder(
          dartOrpcBuilder(BuilderOptions(const {})),
          {
            'a|lib/example.dart': r'''
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
''',
          },
          rootPackage: 'a',
          readerWriter: readerWriter,
        );

        expect(result.succeeded, isTrue);
        expect(
          result.outputs,
          contains(AssetId('a', 'lib/example.dart_orpc.g.part')),
        );
        final generatedOutput = readerWriter.testing.readString(
          AssetId(
            'a',
            '.dart_tool/build/generated/a/lib/example.dart_orpc.g.part',
          ),
        );
        expect(
          generatedOutput,
          contains(
            'RpcProcedureRegistry _\$createAppModuleProcedureRegistry() {',
          ),
        );
        expect(generatedOutput, contains("method: 'user.getById',"));
        expect(generatedOutput, contains("method: 'user.status',"));
        expect(generatedOutput, contains('RpcProcedure<Null, UserStatusDto>('));
        expect(
          generatedOutput,
          contains('RpcHttpApp _\$buildAppModuleRpcApp() {'),
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
      'When provider dependencies cannot be resolved then the builder reports a generation error',
      () async {
        final readerWriter = TestReaderWriter(rootPackage: 'a');
        await readerWriter.testing.loadIsolateSources();

        final result = await testBuilder(
          dartOrpcBuilder(BuilderOptions(const {})),
          {
            'a|lib/example.dart': r'''
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
''',
          },
          rootPackage: 'a',
          readerWriter: readerWriter,
        );

        expect(result.succeeded, isFalse);
        expect(
          result.errors.join('\n'),
          contains(
            'Unable to resolve provider constructor dependencies for: UserService.',
          ),
        );
      },
    );
  });
}

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';

import 'support/generator_test_harness.dart';

void main() {
  group('RpcModuleGenerator production contracts', () {
    test('generated output is deterministic and syntactically valid', () async {
      final firstRun = await runModuleBuilder(_representativeModuleSource);
      final secondRun = await runModuleBuilder(_representativeModuleSource);

      expect(firstRun.succeeded, isTrue);
      expect(secondRun.succeeded, isTrue);
      expect(secondRun.generatedOutput, firstRun.generatedOutput);
      expect(parseString(content: firstRun.generatedOutput).errors, isEmpty);
    });

    test('a library without a module produces no module output', () async {
      final run = await runModuleBuilder(_dtoOnlySource);

      expect(run.succeeded, isTrue);
      expect(run.moduleOutputs, isEmpty);
      expect(run.generatedFieldRefs, contains('ConstructorDtoFields'));
    });

    test('multiple modules generate isolated names in one library', () async {
      final run = await runModuleBuilder(_multipleModulesSource);

      expect(run.succeeded, isTrue);
      expect(
        run.generatedOutput,
        contains('extension DartOrpcChildModuleGenerated on ChildModule'),
      );
      expect(
        run.generatedOutput,
        contains('extension DartOrpcAppModuleGenerated on AppModule'),
      );
      expect(run.generatedOutput, contains('class AppClientRoot'));
      expect(parseString(content: run.generatedOutput).errors, isEmpty);
    });

    test('nested Luthor DTOs become OpenAPI schema components', () async {
      final run = await runModuleBuilder(_nestedLuthorDtosSource);

      expect(run.succeeded, isTrue);
      expect(run.generatedOutput, contains("name: 'ChildDto'"));
      expect(run.generatedOutput, contains(r'validator: $ChildDtoSchema'));
      expect(run.generatedOutput, contains("name: 'ParentDto'"));
      expect(run.generatedOutput, contains(r'validator: $ParentDtoSchema'));
    });

    test('explicit REST body procedures generate body decoding', () async {
      final run = await runModuleBuilder(_explicitRestBodySource);

      expect(run.succeeded, isTrue);
      expect(
        run.generatedOutput,
        contains('final body = decodeRestBody<UpdateDto>('),
      );
      expect(run.generatedOutput, contains('rawBody: request.body,'));
      expect(
        run.generatedOutput,
        contains('source: ProcedureParameterSourceKind.body'),
      );
      expect(run.generatedOutput, isNot(contains('Future<UpdateDto> update(')));
    });

    test('DTO field references fall back to constructor parameters', () async {
      final run = await runModuleBuilder(_dtoOnlySource);

      expect(run.generatedFieldRefs, contains('ConstructorDtoFields'));
      expect(
        run.generatedFieldRefs,
        contains(
          "static const count = RpcInputField<ConstructorDto>('count');",
        ),
      );
      expect(
        run.generatedFieldRefs,
        contains("static const name = RpcInputField<ConstructorDto>('name');"),
      );
      expect(run.generatedFieldRefs, isNot(contains('_PrivateDtoFields')));
      expect(run.generatedFieldRefs, isNot(contains('IgnoredFieldsFields')));
    });

    test('duplicate RPC methods fail during generation', () async {
      final run = await runModuleBuilder(_duplicateRpcMethodsSource);

      expect(run.succeeded, isFalse);
      expect(
        run.errors.join('\n'),
        contains('declares duplicate RPC method "user.get"'),
      );
    });

    test('duplicate REST routes fail during generation', () async {
      final run = await runModuleBuilder(_duplicateRestRoutesSource);

      expect(run.succeeded, isFalse);
      expect(
        run.errors.join('\n'),
        contains('declares duplicate REST route "GET /users/:"'),
      );
    });

    test('duplicate client namespaces fail during generation', () async {
      final run = await runModuleBuilder(_duplicateClientNamespacesSource);

      expect(run.succeeded, isFalse);
      expect(
        run.errors.join('\n'),
        contains(
          'resolves RPC client namespace "user" from more than one source',
        ),
      );
    });

    test('unannotated procedure parameters fail during generation', () async {
      final run = await runModuleBuilder(_unannotatedParameterSource);

      expect(run.succeeded, isFalse);
      expect(
        run.errors.join('\n'),
        contains(
          'only supports an optional RpcContext, one @RpcInput parameter',
        ),
      );
    });
  });
}

const _representativeModuleSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';

part 'example.g.dart';

@Module(controllers: [UserController], providers: [UserService])
final class AppModule {
  const AppModule();
}

final class UserService {
  UserDto find(String id) => UserDto(id: id);
}

@Controller('user')
final class UserController {
  UserController(this.service);

  final UserService service;

  @RpcMethod(name: 'find', path: RestMapping.get('/users/:id'))
  UserDto find(RpcContext context, @PathParam() String id) {
    return service.find(id);
  }
}

final class UserDto {
  const UserDto({required this.id});

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(id: json['id'] as String);
  }

  final String id;

  Map<String, dynamic> toJson() => {'id': id};
}
''';

const _dtoOnlySource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

final class ConstructorDto {
  const ConstructorDto({required String name, int count = 0});

  factory ConstructorDto.fromJson(Map<String, dynamic> json) {
    return ConstructorDto(
      name: json['name'] as String,
      count: json['count'] as int,
    );
  }

  Map<String, dynamic> toJson() => const {};
}

final class _PrivateDto {
  const _PrivateDto(this.value);

  factory _PrivateDto.fromJson(Map<String, dynamic> json) {
    return _PrivateDto(json['value'] as String);
  }

  final String value;

  Map<String, dynamic> toJson() => {'value': value};
}

final class IgnoredFields {
  const IgnoredFields({required this.value});

  factory IgnoredFields.fromJson(Map<String, dynamic> json) {
    return IgnoredFields(value: json['value'] as String);
  }

  final String value;

  Map<String, dynamic> toJson() => {'value': value};
}
''';

const _multipleModulesSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [AppController])
final class ChildModule {
  const ChildModule();
}

@Controller('child')
final class AppController {
  @RpcMethod()
  String ping() => 'pong';
}

@Module(imports: [ChildModule], controllers: [RootController])
final class AppModule {
  const AppModule();
}

@Controller('root')
final class RootController {
  @RpcMethod()
  String ping() => 'pong';
}
''';

const _nestedLuthorDtosSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';
import 'package:luthor/luthor.dart';

part 'example.g.dart';

@Module(controllers: [ParentController])
final class AppModule {
  const AppModule();
}

@Controller('parent')
final class ParentController {
  @RpcMethod(path: RestMapping.post('/parents'))
  ParentDto create(@RpcInput() ParentDto input) => input;
}

@luthor
final class ParentDto {
  const ParentDto({required this.children});

  factory ParentDto.fromJson(Map<String, dynamic> json) {
    return const ParentDto(children: []);
  }

  final List<ChildDto> children;

  Map<String, dynamic> toJson() => const {'children': []};
}

@luthor
final class ChildDto {
  const ChildDto({required this.name});

  factory ChildDto.fromJson(Map<String, dynamic> json) {
    return ChildDto(name: json['name'] as String);
  }

  final String name;

  Map<String, dynamic> toJson() => {'name': name};
}
''';

const _explicitRestBodySource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [UserController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class UserController {
  @RpcMethod(path: RestMapping.put('/users/:id'))
  UpdateDto update(@PathParam() String id, @Body() UpdateDto body) => body;
}

final class UpdateDto {
  const UpdateDto({required this.name});

  factory UpdateDto.fromJson(Map<String, dynamic> json) {
    return UpdateDto(name: json['name'] as String);
  }

  final String name;

  Map<String, dynamic> toJson() => {'name': name};
}
''';

const _duplicateRpcMethodsSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [FirstController, SecondController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class FirstController {
  @RpcMethod(name: 'get')
  String get() => 'first';
}

@Controller('user')
final class SecondController {
  @RpcMethod(name: 'get')
  String get() => 'second';
}
''';

const _duplicateRestRoutesSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [FirstController, SecondController])
final class AppModule {
  const AppModule();
}

@Controller('first')
final class FirstController {
  @RpcMethod(path: RestMapping.get('/users/:id'))
  String get(@PathParam() String id) => id;
}

@Controller('second')
final class SecondController {
  @RpcMethod(path: RestMapping.get('/users/:slug'))
  String get(@PathParam() String slug) => slug;
}
''';

const _duplicateClientNamespacesSource = r'''
library example;

import 'package:dart_orpc_annotations/dart_orpc_annotations.dart';

part 'example.g.dart';

@Module(controllers: [FirstController, SecondController])
final class AppModule {
  const AppModule();
}

@Controller('user')
final class FirstController {
  @RpcMethod()
  String first() => 'first';
}

@Controller('user')
final class SecondController {
  @RpcMethod()
  String second() => 'second';
}
''';

const _unannotatedParameterSource = r'''
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
  String get(String id) => id;
}
''';

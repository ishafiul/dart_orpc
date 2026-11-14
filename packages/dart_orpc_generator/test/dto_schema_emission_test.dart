import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';

import 'support/generator_test_harness.dart';

const _source = r'''
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
  const ParentDto({required this.children, this.note});

  factory ParentDto.fromJson(Map<String, dynamic> json) {
    return const ParentDto(children: []);
  }

  final List<ChildDto> children;
  final String? note;

  Map<String, dynamic> toJson() => const {'children': []};
}

@luthor
final class ChildDto {
  const ChildDto({required this.name, required this.code});

  factory ChildDto.fromJson(Map<String, dynamic> json) {
    return ChildDto(name: json['name'] as String, code: json['code'] as String);
  }

  @HasMin(2)
  @HasMax(40)
  final String name;

  @MatchRegex(r'^[a-z]+$')
  final String code;

  Map<String, dynamic> toJson() => {'name': name, 'code': code};
}
''';

void main() {
  group('Given a module whose procedures use @luthor DTOs', () {
    late GeneratorBuilderRun run;

    setUpAll(() async {
      run = await runModuleBuilder(_source);
    });

    test('When generated then the build succeeds and parses', () {
      expect(run.succeeded, isTrue, reason: run.errors.join('\n'));
      expect(parseString(content: run.generatedOutput).errors, isEmpty);
    });

    test('When generated then each DTO is emitted as const metadata', () {
      final output = _normalized(run.generatedOutput);

      expect(
        output,
        contains(
          _normalized(
            'DtoSchemaRegistry _\$createAppModuleLocalDtoSchemaRegistry() {'
            ' return DtoSchemaRegistry(const [',
          ),
        ),
      );
      expect(
        output,
        contains(_normalized("DtoSchemaMetadata(name: 'ChildDto',")),
      );
      expect(
        output,
        contains(
          _normalized(
            "DtoFieldMetadata(wireName: 'name', type: DtoStringType(), "
            'constraints: DtoFieldConstraints(min: 2, max: 40))',
          ),
        ),
      );
      expect(
        output,
        contains(
          _normalized(
            "DtoFieldMetadata(wireName: 'children', "
            "type: DtoListType(DtoObjectType('ChildDto')))",
          ),
        ),
      );
      expect(
        output,
        contains(
          _normalized(
            "DtoFieldMetadata(wireName: 'note', type: DtoStringType(), "
            'nullable: true, required: false)',
          ),
        ),
      );
    });

    test('When a pattern contains special characters then it is escaped', () {
      expect(
        _normalized(run.generatedOutput),
        contains(_normalized(r"pattern: '^[a-z]+\$'")),
      );
    });

    test('When generated then schemas are ordered by name', () {
      final output = run.generatedOutput;

      expect(
        output.indexOf("name: 'ChildDto'"),
        lessThan(output.indexOf("name: 'ParentDto'")),
      );
    });

    test('When generated then a composed public registry is exposed', () {
      final output = _normalized(run.generatedOutput);

      expect(
        output,
        contains(
          _normalized(
            'DtoSchemaRegistry dartOrpcCreateAppModuleDtoSchemaRegistry() =>',
          ),
        ),
      );
      expect(
        output,
        contains(
          _normalized('..._\$createAppModuleLocalDtoSchemaRegistry().schemas'),
        ),
      );
      expect(
        output,
        contains(
          _normalized(
            'DtoSchemaRegistry dtoSchemaRegistry() => '
            'dartOrpcCreateAppModuleDtoSchemaRegistry();',
          ),
        ),
      );
    });

    test('When generated twice then the output is identical', () async {
      final again = await runModuleBuilder(_source);

      expect(again.generatedOutput, run.generatedOutput);
    });
  });
}

/// Generated code is formatted, so compare without whitespace and trailing
/// commas.
String _normalized(String code) => code
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(',)', ')')
    .replaceAll(',]', ']');

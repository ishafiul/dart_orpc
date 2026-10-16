import 'package:analyzer/dart/element/element.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_orpc_generator/src/analysis/dto_field_discovery.dart';
import 'package:test/test.dart';

void main() {
  group('DTO field discovery', () {
    test('discovers public instance members with their source types', () async {
      await resolveSource(_source, (resolver) async {
        final library = await resolver.findLibraryByName('fixture');
        final dto =
            library?.getClass('MemberDto') ??
            (throw StateError('Missing MemberDto fixture.'));
        final fields = discoverDtoMembers(dto).toList();

        expect(fields.map((field) => field.name).toSet(), {'id', 'label'});
        expect(fields.first.name, 'id');
        expect(fields.first.type.getDisplayString(), 'int');
        expect(fields.first.element, isA<FieldElement>());
        expect(
          fields
              .where((field) => field.element is GetterElement)
              .map((field) => field.name),
          containsAll(['id', 'label']),
        );
      });
    });

    test(
      'constructor candidates include members and extra unnamed parameters',
      () async {
        await resolveSource(_source, (resolver) async {
          final library = await resolver.findLibraryByName('fixture');
          final dto =
              library?.getClass('MemberDto') ??
              (throw StateError('Missing MemberDto fixture.'));
          final parameters = discoverDtoConstructorParameters(dto).toList();
          expect(parameters.map((field) => field.name), [
            'id',
            'constructorOnly',
          ]);
          expect(parameters.last.type.getDisplayString(), 'String');
          expect(parameters.last.element, isA<FormalParameterElement>());
        });
      },
    );

    test(
      'unnamed factory parameters remain available to constructor fallback',
      () async {
        await resolveSource(_source, (resolver) async {
          final library = await resolver.findLibraryByName('fixture');
          final dto =
              library?.getClass('FactoryDto') ??
              (throw StateError('Missing FactoryDto fixture.'));
          expect(discoverDtoMembers(dto), isEmpty);
          expect(
            discoverDtoConstructorParameters(dto).map((field) => field.name),
            ['value'],
          );
        });
      },
    );

    test('named constructor parameters do not become DTO fields', () async {
      await resolveSource(_source, (resolver) async {
        final library = await resolver.findLibraryByName('fixture');
        final dto =
            library?.getClass('NamedOnlyDto') ??
            (throw StateError('Missing NamedOnlyDto fixture.'));
        expect(discoverDtoMembers(dto), isEmpty);
        expect(discoverDtoConstructorParameters(dto), isEmpty);
      });
    });
  });
}

const _source = '''
library fixture;

class MemberDto {
  MemberDto(this.id, String constructorOnly, [int _internal = 0]);
  MemberDto.named(int namedOnly) : id = 0;
  final int id;
  String get label => 'example';
  static const int ignored = 1;
  static String get ignoredGetter => 'static';
  final int _private = 0;
  String get _privateGetter => 'private';
}

abstract class FactoryDto {
  factory FactoryDto({required int value}) = FactoryValue;
}

class FactoryValue implements FactoryDto {
  FactoryValue({required int value});
}

class NamedOnlyDto {
  NamedOnlyDto.named(int namedOnly);
}
''';

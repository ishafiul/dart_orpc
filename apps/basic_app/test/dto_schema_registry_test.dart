import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  group('Given the generated basic_app DTO schema registry', () {
    late DtoSchemaRegistry registry;

    setUp(() {
      registry = const AppModule().dtoSchemaRegistry();
    });

    test(
      'When listed then it covers the same DTOs as the OpenAPI registry',
      () {
        expect(
          registry.names.toSet(),
          const AppModule().openApiSchemaRegistry().names.toSet(),
        );
      },
    );

    test('When a validated field is read then its constraint is present', () {
      final title = _field(registry, 'CreateTodoDto', 'title');

      expect(title.type, isA<DtoStringType>());
      expect(title.required, isTrue);
      expect(title.constraints.min, 1);
    });

    test('When a DateTime field is read then it is a date-time string', () {
      final createdAt = _field(registry, 'TodoResponseDto', 'createdAt');

      expect(createdAt.type, isA<DtoStringType>());
      expect(createdAt.constraints.format, DtoStringFormat.dateTime);
    });

    test('When a nested DTO field is read then it references the DTO', () {
      final metadata = _field(registry, 'TodoResponseDto', 'metadata');

      expect(
        metadata.type,
        isA<DtoObjectType>().having(
          (type) => type.component,
          'component',
          'TodoMetadataDto',
        ),
      );
      expect(metadata.nullable, isTrue);
      expect(metadata.required, isFalse);
    });
  });
}

DtoFieldMetadata _field(
  DtoSchemaRegistry registry,
  String schema,
  String wireName,
) =>
    registry[schema]!.fields.singleWhere((field) => field.wireName == wireName);

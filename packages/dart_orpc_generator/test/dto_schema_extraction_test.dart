import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_generator/src/analysis/dto_schema_extraction.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

const _fixture = r'''
library fixture;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:luthor/luthor.dart';

bool _check(Object? value) => true;

@luthor
class AddressDto {
  const AddressDto({required this.city});

  @HasMin(1)
  final String city;
}

class PlainValue {
  const PlainValue();
}

enum Role { admin, member }

enum Level {
  @JsonValue(1)
  low,
  @JsonValue(2)
  high,
}

@JsonEnum(fieldRename: FieldRename.snake)
enum Status { inProgress, done }

@JsonEnum(valueField: 'code')
enum Coded {
  one('1');

  const Coded(this.code);
  final String code;
}

@luthor
@JsonSerializable(fieldRename: FieldRename.snake)
class UserDto {
  const UserDto({
    @IsEmail() required this.emailAddress,
    @JsonKey(name: 'nick') @MatchRegex(r'^[a-z]+$') @HasLength(8) this.nickName,
    @HasMin(18) @HasMax(130) required this.age,
    required this.score,
    required this.active,
    this.extra,
    required this.address,
    this.backup,
    required this.tags,
    required this.counts,
    required this.role,
    required this.level,
    required this.status,
    required this.createdAt,
    @WithCustomValidator(_check) required this.checked,
    this.withDefault = 3,
    @JsonKey(defaultValue: 'x') required this.keyDefault,
    @JsonKey(required: true) this.mustSend,
    @JsonKey(includeFromJson: false) this.hidden,
    @JsonKey(includeToJson: false) this.inputOnly,
    @JsonKey(ignore: true) this.ignored,
  });

  final String emailAddress;
  final String? nickName;
  final int age;
  final double score;
  final bool active;
  final Object? extra;
  final AddressDto address;
  final AddressDto? backup;
  final List<String?> tags;
  final Map<String, int> counts;
  final Role role;
  final Level level;
  final Status status;
  final DateTime createdAt;
  final String checked;
  final int withDefault;
  final String keyDefault;
  final String? mustSend;
  final String? hidden;
  final String? inputOnly;
  final String? ignored;
}

@luthor
abstract class FreezedDto {
  const factory FreezedDto({
    @Default(3) int count,
    @JsonKey(name: 'full_name') @HasMax(40) required String fullName,
  }) = _FreezedDto;
}

class _FreezedDto implements FreezedDto {
  const _FreezedDto({this.count = 3, required this.fullName});

  final int count;
  final String fullName;
}

@luthor
@JsonSerializable(fieldRename: FieldRename.pascal)
class PascalDto {
  const PascalDto({required this.firstName});
  final String firstName;
}

@luthor
@JsonSerializable(fieldRename: FieldRename.screamingSnake)
class ScreamingDto {
  const ScreamingDto({required this.firstName});
  final String firstName;
}

@luthor
@JsonSerializable(fieldRename: FieldRename.kebab)
class KebabDto {
  const KebabDto({required this.firstName});
  final String firstName;
}

@luthor
class EmptyDto {
  const EmptyDto();
}

@luthor
class GenericDto<T> {
  const GenericDto({required this.value});

  final T value;
}

@luthor
sealed class SealedDto {
  const SealedDto();
}

@luthor
abstract class UnionDto {
  const factory UnionDto.success({required String value}) = _Success;
  const factory UnionDto.failure({required String reason}) = _Failure;
}

class _Success implements UnionDto {
  const _Success({required this.value});
  final String value;
}

class _Failure implements UnionDto {
  const _Failure({required this.reason});
  final String reason;
}

@luthor
class IntKeyMapDto {
  const IntKeyMapDto({required this.byId});

  final Map<int, String> byId;
}

@luthor
class PlainClassFieldDto {
  const PlainClassFieldDto({required this.value});

  final PlainValue value;
}

@luthor
class CodedEnumDto {
  const CodedEnumDto({required this.coded});

  final Coded coded;
}
''';

void main() {
  group('Given a DTO with json_serializable naming', () {
    test('When extracted then wire names follow fieldRename and JsonKey', () {
      return _extract('UserDto', (extraction) {
        final names = extraction.schema.fields.map((field) => field.wireName);

        expect(names, contains('email_address'));
        expect(names, contains('nick'));
        expect(names, contains('created_at'));
        expect(names, isNot(contains('nickName')));
      });
    });

    test('When extracted then excluded and ignored fields are absent', () {
      return _extract('UserDto', (extraction) {
        final names = extraction.schema.fields.map((field) => field.wireName);

        expect(names, isNot(contains('hidden')));
        expect(names, isNot(contains('input_only')));
        expect(names, isNot(contains('ignored')));
      });
    });

    test('When extracted then fields keep constructor order', () {
      return _extract('UserDto', (extraction) {
        expect(extraction.schema.name, 'UserDto');
        expect(
          extraction.schema.fields.take(3).map((field) => field.wireName),
          ['email_address', 'nick', 'age'],
        );
      });
    });
  });

  group('Given each json_serializable field rename', () {
    for (final (dto, wireName) in [
      ('PascalDto', 'FirstName'),
      ('ScreamingDto', 'FIRST_NAME'),
      ('KebabDto', 'first-name'),
    ]) {
      test('When $dto is extracted then the wire name is $wireName', () {
        return _extract(dto, (extraction) {
          expect(extraction.schema.fields.single.wireName, wireName);
        });
      });
    }
  });

  group('Given a DTO with optional and nullable fields', () {
    test('When extracted then required follows nullability and defaults', () {
      return _extract('UserDto', (extraction) {
        final fields = _byName(extraction);

        expect(fields['email_address']!.required, isTrue);
        expect(fields['nick']!.required, isFalse);
        expect(fields['nick']!.nullable, isTrue);
        expect(fields['with_default']!.required, isFalse);
        expect(fields['key_default']!.required, isFalse);
        expect(fields['must_send']!.required, isTrue);
        expect(fields['must_send']!.nullable, isTrue);
      });
    });
  });

  group('Given a DTO covering every supported field type', () {
    test('When extracted then each Dart type maps to its JSON type', () {
      return _extract('UserDto', (extraction) {
        final fields = _byName(extraction);

        expect(_describe(fields['age']!.type), 'integer');
        expect(_describe(fields['score']!.type), 'number');
        expect(_describe(fields['active']!.type), 'boolean');
        expect(_describe(fields['extra']!.type), 'any');
        expect(fields['extra']!.nullable, isTrue);
        expect(_describe(fields['address']!.type), 'object AddressDto');
        expect(_describe(fields['backup']!.type), 'object AddressDto');
        expect(fields['backup']!.nullable, isTrue);
        expect(
          _describe(fields['tags']!.type),
          'list of string (nullable elements)',
        );
        expect(_describe(fields['counts']!.type), 'map of integer');
      });
    });

    test('When extracted then enums use their serialized values', () {
      return _extract('UserDto', (extraction) {
        final fields = _byName(extraction);

        expect(_describe(fields['role']!.type), 'enum admin, member');
        expect(_describe(fields['level']!.type), 'enum 1, 2');
        expect(_describe(fields['status']!.type), 'enum in_progress, done');
      });
    });

    test('When extracted then DateTime is a date-time string', () {
      return _extract('UserDto', (extraction) {
        final createdAt = _byName(extraction)['created_at']!;

        expect(_describe(createdAt.type), 'string');
        expect(createdAt.constraints.format, DtoStringFormat.dateTime);
      });
    });

    test('When extracted then referenced DTOs are reported once', () {
      return _extract('UserDto', (extraction) {
        expect(extraction.references.map((element) => element.displayName), [
          'AddressDto',
        ]);
      });
    });
  });

  group('Given luthor constraint annotations', () {
    test('When extracted then constraints are recorded', () {
      return _extract('UserDto', (extraction) {
        final fields = _byName(extraction);

        expect(
          fields['email_address']!.constraints.format,
          DtoStringFormat.email,
        );
        expect(fields['nick']!.constraints.pattern, r'^[a-z]+$');
        expect(fields['nick']!.constraints.length, 8);
        expect(fields['age']!.constraints.min, 18);
        expect(fields['age']!.constraints.max, 130);
        expect(fields['score']!.constraints.isEmpty, isTrue);
      });
    });

    test('When a field has a custom validator then it is flagged', () {
      return _extract('UserDto', (extraction) {
        final fields = _byName(extraction);

        expect(fields['checked']!.customValidation, isTrue);
        expect(fields['age']!.customValidation, isFalse);
      });
    });

    test('When annotations sit on the field then they are read', () {
      return _extract('AddressDto', (extraction) {
        expect(extraction.schema.fields.single.wireName, 'city');
        expect(extraction.schema.fields.single.constraints.min, 1);
      });
    });
  });

  group('Given a freezed-style factory DTO', () {
    test('When extracted then factory parameters define the fields', () {
      return _extract('FreezedDto', (extraction) {
        final fields = _byName(extraction);

        expect(fields.keys, ['count', 'full_name']);
        expect(fields['count']!.required, isFalse);
        expect(fields['full_name']!.required, isTrue);
        expect(fields['full_name']!.constraints.max, 40);
      });
    });
  });

  group('Given a DTO without fields', () {
    test('When extracted then the schema is empty', () {
      return _extract('EmptyDto', (extraction) {
        expect(extraction.schema.fields, isEmpty);
        expect(extraction.references, isEmpty);
      });
    });
  });

  group('Given DTO shapes that cannot be described', () {
    for (final (dto, message) in [
      ('GenericDto', 'DTO "GenericDto" is generic'),
      ('SealedDto', 'DTO "SealedDto" is sealed'),
      ('UnionDto', 'DTO "UnionDto" is a union'),
      ('IntKeyMapDto', 'DTO "IntKeyMapDto" field "byId"'),
      ('PlainClassFieldDto', 'DTO "PlainClassFieldDto" field "value"'),
      ('CodedEnumDto', 'DTO "CodedEnumDto" field "coded"'),
    ]) {
      test('When $dto is extracted then the build fails naming it', () {
        return _extractFailure(dto, contains(message));
      });
    }
  });
}

Future<void> _extract(
  String className,
  void Function(DtoSchemaExtraction extraction) body,
) => resolveSource(_fixture, (resolver) async {
  body(extractDtoSchema(await _class(resolver, className)));
}, readAllSourcesFromFilesystem: true);

Future<void> _extractFailure(String className, Matcher message) =>
    resolveSource(_fixture, (resolver) async {
      final dto = await _class(resolver, className);
      expect(
        () => extractDtoSchema(dto),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (error) => error.message,
            'message',
            message,
          ),
        ),
      );
    }, readAllSourcesFromFilesystem: true);

Future<InterfaceElement> _class(Resolver resolver, String name) async {
  final library = await resolver.findLibraryByName('fixture');
  return library?.getClass(name) ?? (throw StateError('Missing $name.'));
}

Map<String, DtoFieldMetadata> _byName(DtoSchemaExtraction extraction) => {
  for (final field in extraction.schema.fields) field.wireName: field,
};

String _describe(DtoFieldType type) => switch (type) {
  DtoStringType() => 'string',
  DtoIntegerType() => 'integer',
  DtoNumberType() => 'number',
  DtoBooleanType() => 'boolean',
  DtoAnyType() => 'any',
  DtoObjectType(:final component) => 'object $component',
  DtoListType(:final element, :final elementNullable) =>
    'list of ${_describe(element)}'
        '${elementNullable ? ' (nullable elements)' : ''}',
  DtoMapType(:final value, :final valueNullable) =>
    'map of ${_describe(value)}${valueNullable ? ' (nullable values)' : ''}',
  DtoEnumType(:final values) => 'enum ${values.join(', ')}',
};

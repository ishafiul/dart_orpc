import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

const _address = DtoSchemaMetadata(
  name: 'AddressDto',
  fields: [
    DtoFieldMetadata(
      wireName: 'city',
      type: DtoStringType(),
      constraints: DtoFieldConstraints(min: 1, max: 80),
    ),
  ],
);

const _user = DtoSchemaMetadata(
  name: 'UserDto',
  fields: [
    DtoFieldMetadata(
      wireName: 'email',
      type: DtoStringType(),
      constraints: DtoFieldConstraints(format: DtoStringFormat.email),
    ),
    DtoFieldMetadata(
      wireName: 'nick_name',
      type: DtoStringType(),
      nullable: true,
      required: false,
      constraints: DtoFieldConstraints(pattern: r'^[a-z]+$', length: 8),
    ),
    DtoFieldMetadata(wireName: 'age', type: DtoIntegerType()),
    DtoFieldMetadata(wireName: 'score', type: DtoNumberType()),
    DtoFieldMetadata(wireName: 'active', type: DtoBooleanType()),
    DtoFieldMetadata(wireName: 'extra', type: DtoAnyType()),
    DtoFieldMetadata(wireName: 'address', type: DtoObjectType('AddressDto')),
    DtoFieldMetadata(
      wireName: 'tags',
      type: DtoListType(DtoStringType(), elementNullable: true),
    ),
    DtoFieldMetadata(wireName: 'counts', type: DtoMapType(DtoIntegerType())),
    DtoFieldMetadata(wireName: 'role', type: DtoEnumType(['admin', 'member'])),
    DtoFieldMetadata(
      wireName: 'checked',
      type: DtoStringType(),
      customValidation: true,
    ),
  ],
);

void main() {
  group('Given a DTO field declared with only a wire name and type', () {
    const field = DtoFieldMetadata(wireName: 'id', type: DtoIntegerType());

    test('When read then it is required and not nullable', () {
      expect(field.required, isTrue);
      expect(field.nullable, isFalse);
    });

    test('When read then it has no constraints or custom validation', () {
      expect(field.constraints.isEmpty, isTrue);
      expect(field.customValidation, isFalse);
    });
  });

  group('Given DTO metadata covering every field type', () {
    test('When the types are matched then each case is reachable', () {
      final described = [
        for (final field in _user.fields) _describe(field.type),
      ];

      expect(described, [
        'string',
        'string',
        'integer',
        'number',
        'boolean',
        'any',
        'object AddressDto',
        'list of string (nullable elements)',
        'map of integer',
        'enum admin, member',
        'string',
      ]);
    });

    test('When constraints are read then they keep their values', () {
      final nickName = _user.fields[1].constraints;

      expect(nickName.pattern, r'^[a-z]+$');
      expect(nickName.length, 8);
      expect(nickName.isEmpty, isFalse);
      expect(_user.fields.first.constraints.format, DtoStringFormat.email);
      expect(_address.fields.single.constraints.min, 1);
      expect(_address.fields.single.constraints.max, 80);
    });
  });

  group('Given metadata built from mutable lists', () {
    late List<DtoFieldMetadata> fields;
    late List<Object> roles;
    late DtoSchemaMetadata schema;

    setUp(() {
      roles = ['admin'];
      fields = [
        const DtoFieldMetadata(wireName: 'id', type: DtoIntegerType()),
        DtoFieldMetadata(
          wireName: 'roles',
          type: DtoListType(DtoEnumType(roles)),
        ),
      ];
      schema = DtoSchemaMetadata(name: 'MutableDto', fields: fields);
      DtoSchemaRegistry([schema]);
    });

    test('When the fields list changes after registration then the schema '
        'keeps its validated fields', () {
      fields.add(const DtoFieldMetadata(wireName: 'id', type: DtoStringType()));

      expect(schema.fields.map((field) => field.wireName), ['id', 'roles']);
    });

    test('When enum values change after registration then the enum keeps '
        'its validated values', () {
      roles.add('member');

      final type = schema.fields.last.type as DtoListType;
      expect((type.element as DtoEnumType).values, ['admin']);
    });

    test('When the exposed collections are mutated then it fails', () {
      final type = schema.fields.last.type as DtoListType;

      expect(
        () => schema.fields.add(
          const DtoFieldMetadata(wireName: 'x', type: DtoStringType()),
        ),
        throwsUnsupportedError,
      );
      expect(
        () => (type.element as DtoEnumType).values.add('x'),
        throwsUnsupportedError,
      );
    });
  });

  group('Given a DtoSchemaRegistry', () {
    late DtoSchemaRegistry registry;

    setUp(() {
      registry = DtoSchemaRegistry(const [_address, _user]);
    });

    test('When indexed then schemas are found by name', () {
      expect(registry['UserDto'], same(_user));
      expect(registry['MissingDto'], isNull);
    });

    test('When listed then names keep registration order', () {
      expect(registry.names, ['AddressDto', 'UserDto']);
      expect(registry.schemas, [_address, _user]);
    });

    test('When two schemas share a name then construction fails', () {
      expect(
        () => DtoSchemaRegistry(const [_user, _user]),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Duplicate DTO schema "UserDto".',
          ),
        ),
      );
    });

    test('When one schema repeats a wire name then construction fails', () {
      expect(
        () => DtoSchemaRegistry(const [
          DtoSchemaMetadata(
            name: 'BrokenDto',
            fields: [
              DtoFieldMetadata(wireName: 'id', type: DtoIntegerType()),
              DtoFieldMetadata(wireName: 'id', type: DtoStringType()),
            ],
          ),
        ]),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Duplicate wire name "id" in DTO schema "BrokenDto".',
          ),
        ),
      );
    });

    test('When a schema refers to an unregistered DTO then it is accepted', () {
      final local = DtoSchemaRegistry(const [
        DtoSchemaMetadata(
          name: 'OrderDto',
          fields: [
            DtoFieldMetadata(
              wireName: 'customer',
              type: DtoObjectType('ImportedCustomerDto'),
            ),
          ],
        ),
      ]);

      expect(local.names, ['OrderDto']);
    });
  });
}

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

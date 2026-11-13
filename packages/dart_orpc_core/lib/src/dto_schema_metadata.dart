/// Build-time description of a DTO's JSON shape and constraints.
///
/// The generator extracts these from `@luthor` DTOs; transports and OpenAPI
/// read them without depending on the validation library.
final class DtoSchemaMetadata {
  const DtoSchemaMetadata({
    required this.name,
    required List<DtoFieldMetadata> fields,
  }) : _fields = fields;

  /// The component name, unique within a [DtoSchemaRegistry].
  final String name;

  final List<DtoFieldMetadata> _fields;

  // Weak keys retain const construction without a permanent global cache.
  static final _snapshots = Expando<List<DtoFieldMetadata>>();

  /// Fields in declaration order, as an immutable snapshot taken on
  /// [prepare] or first use.
  List<DtoFieldMetadata> get fields =>
      _snapshots[this] ??= List.unmodifiable(_fields);

  /// Snapshots [fields] and every nested enum's values, so later changes to
  /// the lists passed to the constructors are not observed.
  void prepare() {
    for (final field in fields) {
      field.type._prepare();
    }
  }
}

/// One JSON property of a DTO.
final class DtoFieldMetadata {
  const DtoFieldMetadata({
    required this.wireName,
    required this.type,
    this.nullable = false,
    this.required = true,
    this.constraints = const DtoFieldConstraints(),
    this.customValidation = false,
  });

  /// The JSON key, after `@JsonKey(name:)` and field renaming.
  final String wireName;

  final DtoFieldType type;

  /// Whether the value may be `null`.
  final bool nullable;

  /// Whether input must contain the key.
  final bool required;

  final DtoFieldConstraints constraints;

  /// Whether the field has validation rules that can't be described
  /// statically, such as a custom validator.
  final bool customValidation;
}

/// The JSON type of a DTO field.
sealed class DtoFieldType {
  const DtoFieldType();

  void _prepare() {}
}

final class DtoStringType extends DtoFieldType {
  const DtoStringType();
}

final class DtoIntegerType extends DtoFieldType {
  const DtoIntegerType();
}

final class DtoNumberType extends DtoFieldType {
  const DtoNumberType();
}

final class DtoBooleanType extends DtoFieldType {
  const DtoBooleanType();
}

/// Any JSON value.
final class DtoAnyType extends DtoFieldType {
  const DtoAnyType();
}

/// A nested DTO, referenced by its [DtoSchemaMetadata.name].
final class DtoObjectType extends DtoFieldType {
  const DtoObjectType(this.component);

  final String component;
}

final class DtoListType extends DtoFieldType {
  const DtoListType(this.element, {this.elementNullable = false});

  final DtoFieldType element;
  final bool elementNullable;

  @override
  void _prepare() => element._prepare();
}

/// A JSON object with string keys and values of one type.
final class DtoMapType extends DtoFieldType {
  const DtoMapType(this.value, {this.valueNullable = false});

  final DtoFieldType value;
  final bool valueNullable;

  @override
  void _prepare() => value._prepare();
}

/// A fixed set of serialized values, such as an enum's JSON values.
final class DtoEnumType extends DtoFieldType {
  const DtoEnumType(List<Object> values) : _values = values;

  final List<Object> _values;

  static final _snapshots = Expando<List<Object>>();

  /// The allowed values, as an immutable snapshot taken on preparation or
  /// first use.
  List<Object> get values => _snapshots[this] ??= List.unmodifiable(_values);

  @override
  void _prepare() => values;
}

/// Declarative constraints on a DTO field.
///
/// [min], [max] and [length] apply to string length, list size, or numeric
/// value, depending on the field type.
final class DtoFieldConstraints {
  const DtoFieldConstraints({
    this.min,
    this.max,
    this.length,
    this.pattern,
    this.format,
  });

  final num? min;
  final num? max;
  final int? length;

  /// A regular expression the string value must match.
  final String? pattern;

  final DtoStringFormat? format;

  bool get isEmpty =>
      min == null &&
      max == null &&
      length == null &&
      pattern == null &&
      format == null;
}

enum DtoStringFormat { email, dateTime, uri, uuid }

/// DTO schemas indexed by name.
final class DtoSchemaRegistry {
  DtoSchemaRegistry(Iterable<DtoSchemaMetadata> schemas)
    : _schemas = _indexSchemas(schemas);

  final Map<String, DtoSchemaMetadata> _schemas;

  Iterable<String> get names => _schemas.keys;

  Iterable<DtoSchemaMetadata> get schemas => _schemas.values;

  DtoSchemaMetadata? operator [](String name) => _schemas[name];

  static Map<String, DtoSchemaMetadata> _indexSchemas(
    Iterable<DtoSchemaMetadata> schemas,
  ) {
    final indexed = <String, DtoSchemaMetadata>{};

    for (final schema in schemas) {
      if (indexed.containsKey(schema.name)) {
        throw StateError('Duplicate DTO schema "${schema.name}".');
      }
      schema.prepare();
      final wireNames = <String>{};
      for (final field in schema.fields) {
        if (!wireNames.add(field.wireName)) {
          throw StateError(
            'Duplicate wire name "${field.wireName}" in DTO schema '
            '"${schema.name}".',
          );
        }
      }

      indexed[schema.name] = schema;
    }

    return Map.unmodifiable(indexed);
  }
}

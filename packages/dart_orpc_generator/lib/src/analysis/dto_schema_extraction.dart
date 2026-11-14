import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:luthor/luthor.dart';
import 'package:source_gen/source_gen.dart';

import 'dto_field_discovery.dart';

const _luthorChecker = TypeChecker.typeNamed(Luthor, inPackage: 'luthor');

/// The schema extracted from one DTO, plus the DTOs its fields reference.
final class DtoSchemaExtraction {
  const DtoSchemaExtraction({required this.schema, required this.references});

  final DtoSchemaMetadata schema;

  /// Referenced DTO classes in first-use order, without duplicates.
  final List<InterfaceElement> references;
}

/// Describes [dto]'s JSON shape and constraints at build time.
///
/// Fields come from the unnamed constructor's parameters, so plain classes
/// and freezed factories both work. Wire names, exclusions and defaults follow
/// json_serializable; constraints come from luthor annotations on the
/// parameter or its field. Shapes that can't be described fail the build with
/// an [InvalidGenerationSourceError] naming the DTO and field.
///
/// [isDto] decides which class types become references; by default, classes
/// annotated with `@luthor`.
DtoSchemaExtraction extractDtoSchema(
  InterfaceElement dto, {
  bool Function(InterfaceElement element)? isDto,
}) {
  return _DtoSchemaExtractor(
    dto,
    isDto ?? _luthorChecker.hasAnnotationOfExact,
  ).extract();
}

final class _DtoSchemaExtractor {
  _DtoSchemaExtractor(this.dto, this.isDto);

  final InterfaceElement dto;
  final bool Function(InterfaceElement element) isDto;
  final List<InterfaceElement> _references = [];

  String get _dtoName => dto.displayName;

  DtoSchemaExtraction extract() {
    _checkShape();
    final rename = _classFieldRename();
    final fields = <DtoFieldMetadata>[];
    for (final candidate in discoverDtoConstructorParameters(dto)) {
      final parameter = candidate.element as FormalParameterElement;
      final field = _field(parameter, rename);
      if (field != null) fields.add(field);
    }
    return DtoSchemaExtraction(
      schema: DtoSchemaMetadata(
        name: _dtoName,
        fields: List.unmodifiable(fields),
      ),
      references: List.unmodifiable(_references),
    );
  }

  void _checkShape() {
    if (dto.typeParameters.isNotEmpty) {
      _fail('DTO "$_dtoName" is generic', dto);
    }
    if (dto case ClassElement(isSealed: true)) {
      _fail('DTO "$_dtoName" is sealed', dto);
    }
    final variants = dto.constructors.where(
      (constructor) =>
          constructor.isFactory &&
          constructor.redirectedConstructor != null &&
          constructor.displayName != 'fromJson' &&
          (constructor.name ?? '').isNotEmpty &&
          constructor.name != 'new',
    );
    if (variants.isNotEmpty) {
      _fail('DTO "$_dtoName" is a union of factory constructors', dto);
    }
  }

  /// Class-level json_serializable settings: rejects converters on the class
  /// or its unnamed constructor, then returns the field rename.
  _FieldRename _classFieldRename() {
    final unnamed = dto.constructors.where(
      (constructor) =>
          (constructor.name ?? '').isEmpty || constructor.name == 'new',
    );
    final elements = [dto, ...unnamed];
    for (final element in elements) {
      if (_hasJsonConverter(element)) {
        _fail(
          'DTO "$_dtoName" uses a JsonConverter on the class or its '
          'constructor, whose JSON types cannot be described',
          element,
        );
      }
      final serializable = _serializable(element);
      final converters = serializable == null
          ? null
          : ConstantReader(serializable).peek('converters');
      if (converters != null && converters.listValue.isNotEmpty) {
        _fail(
          'DTO "$_dtoName" uses JsonSerializable converters, whose JSON '
          'types cannot be described',
          element,
        );
      }
    }
    for (final element in elements) {
      final serializable = _serializable(element);
      if (serializable != null) return _readFieldRename(serializable, element);
    }
    return _FieldRename.none;
  }

  DartObject? _serializable(Element element) =>
      _annotation(element, 'json_annotation', 'JsonSerializable');

  DtoFieldMetadata? _field(
    FormalParameterElement parameter,
    _FieldRename rename,
  ) {
    final sources = <Element>[parameter, ?_declaredField(parameter)];
    final name = parameter.displayName;

    final jsonKey = _firstAnnotation(sources, 'json_annotation', 'JsonKey');
    final jsonKeyReader = jsonKey == null ? null : ConstantReader(jsonKey);
    if (_isTrue(jsonKeyReader, 'ignore') ||
        _isFalse(jsonKeyReader, 'includeFromJson') ||
        _isFalse(jsonKeyReader, 'includeToJson')) {
      return null;
    }

    if (!(jsonKeyReader?.peek('fromJson')?.isNull ?? true) ||
        !(jsonKeyReader?.peek('toJson')?.isNull ?? true)) {
      _fail(
        'DTO "$_dtoName" field "$name" uses JsonKey fromJson/toJson, whose '
        'JSON type cannot be described',
        parameter,
      );
    }
    if (sources.any(_hasJsonConverter)) {
      _fail(
        'DTO "$_dtoName" field "$name" uses a JsonConverter, whose JSON type '
        'cannot be described',
        parameter,
      );
    }

    final type = parameter.type;
    final nullable = _isNullable(type);
    final hasDefault =
        parameter.hasDefaultValue ||
        _firstAnnotation(sources, 'freezed_annotation', 'Default') != null ||
        !(jsonKeyReader?.peek('defaultValue')?.isNull ?? true);
    final required =
        _isTrue(jsonKeyReader, 'required') || (!nullable && !hasDefault);

    var constraints = _constraints(sources);
    if (_isDateTime(type) && constraints.format == null) {
      constraints = _withFormat(constraints, DtoStringFormat.dateTime);
    }

    return DtoFieldMetadata(
      wireName: jsonKeyReader?.peek('name')?.stringValue ?? rename.apply(name),
      type: _type(type, parameter),
      nullable: nullable,
      required: required,
      constraints: constraints,
      customValidation:
          _firstAnnotation(sources, 'luthor', 'WithCustomValidator') != null ||
          _firstAnnotation(sources, 'luthor', 'WithSchemaCustomValidator') !=
              null,
    );
  }

  /// The instance field a constructor parameter initializes: the target of
  /// `this.x`, or the same-named field for parameters assigned elsewhere.
  FieldElement? _declaredField(FormalParameterElement parameter) {
    if (parameter case FieldFormalParameterElement(:final field?)) {
      return field;
    }
    final field = dto.getField(parameter.displayName);
    return field != null && !field.isStatic ? field : null;
  }

  DtoFieldType _type(DartType type, Element field) {
    if (type is DynamicType || type.isDartCoreObject || type is InvalidType) {
      return const DtoAnyType();
    }
    if (type.isDartCoreString || _isDateTime(type))
      return const DtoStringType();
    if (type.isDartCoreInt) return const DtoIntegerType();
    if (type.isDartCoreDouble || type.isDartCoreNum)
      return const DtoNumberType();
    if (type.isDartCoreBool) return const DtoBooleanType();
    if (type is InterfaceType) {
      if (type.isDartCoreList ||
          type.isDartCoreSet ||
          type.isDartCoreIterable) {
        final element = type.typeArguments.single;
        return DtoListType(
          _type(element, field),
          elementNullable: _isNullable(element),
        );
      }
      if (type.isDartCoreMap) {
        final [key, value] = type.typeArguments;
        if (!key.isDartCoreString) {
          _fail(
            'DTO "$_dtoName" field "${field.displayName}" is a map with '
            '"${key.getDisplayString()}" keys; only String keys can be '
            'described',
            field,
          );
        }
        return DtoMapType(
          _type(value, field),
          valueNullable: _isNullable(value),
        );
      }
      final element = type.element;
      if (element is EnumElement)
        return DtoEnumType(_enumValues(element, field));
      if (isDto(element)) {
        if (!_references.contains(element)) _references.add(element);
        return DtoObjectType(element.displayName);
      }
    }
    _fail(
      'DTO "$_dtoName" field "${field.displayName}" has type '
      '"${type.getDisplayString()}", which cannot be described; use a JSON '
      'scalar, DateTime, an enum, a List, a String-keyed Map, or a @luthor DTO',
      field,
    );
  }

  List<Object> _enumValues(EnumElement element, Element field) {
    final jsonEnum = _annotation(element, 'json_annotation', 'JsonEnum');
    final jsonEnumReader = jsonEnum == null ? null : ConstantReader(jsonEnum);
    final valueField = jsonEnumReader?.peek('valueField');
    if (valueField != null && !valueField.isNull) {
      _fail(
        'DTO "$_dtoName" field "${field.displayName}" uses enum '
        '"${element.displayName}" with @JsonEnum(valueField:), which cannot '
        'be described',
        field,
      );
    }
    final rename = jsonEnum == null
        ? _FieldRename.none
        : _readFieldRename(jsonEnum, element);
    return [
      for (final constant in element.constants)
        switch (_annotation(constant, 'json_annotation', 'JsonValue')) {
          final DartObject value => _jsonScalar(value.getField('value'), field),
          null => rename.apply(constant.displayName),
        },
    ];
  }

  Object _jsonScalar(DartObject? value, Element field) {
    final reader = value == null ? null : ConstantReader(value);
    final literal = reader?.literalValue;
    if (literal is String || literal is num || literal is bool) return literal!;
    _fail(
      'DTO "$_dtoName" field "${field.displayName}" uses a @JsonValue that '
      'is not a String, number or bool',
      field,
    );
  }

  DtoFieldConstraints _constraints(List<Element> sources) {
    num? min;
    num? max;
    int? length;
    String? pattern;
    DtoStringFormat? format;
    for (final source in sources) {
      for (final (name, value) in _luthorAnnotations(source)) {
        final reader = ConstantReader(value);
        switch (name) {
          case 'HasMin' || 'HasMinDouble' || 'HasMinNumber':
            min = reader.peek('min')?.literalValue as num?;
          case 'HasMax' || 'HasMaxDouble' || 'HasMaxNumber':
            max = reader.peek('max')?.literalValue as num?;
          case 'HasLength':
            length = reader.peek('length')?.intValue;
          case 'MatchRegex':
            pattern = reader.peek('pattern')?.stringValue;
          case 'IsEmail':
            format = DtoStringFormat.email;
          case 'IsDateTime':
            format = DtoStringFormat.dateTime;
          case 'IsUri':
            format = DtoStringFormat.uri;
          case 'IsUuid':
            format = DtoStringFormat.uuid;
        }
      }
    }
    return DtoFieldConstraints(
      min: min,
      max: max,
      length: length,
      pattern: pattern,
      format: format,
    );
  }

  _FieldRename _readFieldRename(DartObject annotation, Element element) {
    final value = ConstantReader(annotation).peek('fieldRename');
    if (value == null || value.isNull) return _FieldRename.none;
    final name =
        value.objectValue.variable?.displayName ??
        value.objectValue.getField('_name')?.toStringValue();
    return _FieldRename.values.firstWhere(
      (rename) => rename.name == name,
      orElse: () => _fail(
        'DTO "$_dtoName" uses an unsupported fieldRename "$name"',
        element,
      ),
    );
  }

  Never _fail(String message, Element element) {
    throw InvalidGenerationSourceError(
      '$message. OpenAPI schema metadata cannot be generated for it.',
      element: element,
    );
  }
}

/// json_serializable's `FieldRename`, applied to Dart identifiers.
enum _FieldRename {
  none,
  kebab,
  snake,
  pascal,
  screamingSnake;

  static final _upperCase = RegExp('[A-Z]');

  String apply(String name) => switch (this) {
    none => name,
    kebab => _separated(name, '-'),
    snake => _separated(name, '_'),
    pascal =>
      name.isEmpty ? name : '${name[0].toUpperCase()}${name.substring(1)}',
    screamingSnake => _separated(name, '_').toUpperCase(),
  };

  static String _separated(String name, String separator) =>
      name.replaceAllMapped(_upperCase, (match) {
        final lower = match.group(0)!.toLowerCase();
        return match.start > 0 ? '$separator$lower' : lower;
      });
}

/// Whether [element] carries an annotation implementing json_annotation's
/// `JsonConverter`.
bool _hasJsonConverter(Element element) {
  for (final annotation in element.metadata.annotations) {
    final type = annotation.computeConstantValue()?.type;
    if (type is! InterfaceType) continue;
    final isConverter = type.element.allSupertypes.any(
      (supertype) =>
          supertype.element.displayName == 'JsonConverter' &&
          supertype.element.library.uri.pathSegments.firstOrNull ==
              'json_annotation',
    );
    if (isConverter) return true;
  }
  return false;
}

bool _isNullable(DartType type) =>
    type.nullabilitySuffix == NullabilitySuffix.question || type is DynamicType;

bool _isDateTime(DartType type) =>
    type is InterfaceType &&
    type.element.displayName == 'DateTime' &&
    type.element.library.isDartCore;

bool _isTrue(ConstantReader? reader, String field) =>
    reader?.peek(field)?.literalValue == true;

bool _isFalse(ConstantReader? reader, String field) =>
    reader?.peek(field)?.literalValue == false;

DtoFieldConstraints _withFormat(
  DtoFieldConstraints constraints,
  DtoStringFormat format,
) => DtoFieldConstraints(
  min: constraints.min,
  max: constraints.max,
  length: constraints.length,
  pattern: constraints.pattern,
  format: format,
);

DartObject? _firstAnnotation(
  List<Element> elements,
  String package,
  String name,
) {
  for (final element in elements) {
    final annotation = _annotation(element, package, name);
    if (annotation != null) return annotation;
  }
  return null;
}

DartObject? _annotation(Element element, String package, String name) {
  for (final (annotationName, value) in _annotationsFrom(element, package)) {
    if (annotationName == name) return value;
  }
  return null;
}

Iterable<(String, DartObject)> _luthorAnnotations(Element element) =>
    _annotationsFrom(element, 'luthor');

Iterable<(String, DartObject)> _annotationsFrom(
  Element element,
  String package,
) sync* {
  for (final annotation in element.metadata.annotations) {
    final value = annotation.computeConstantValue();
    final type = value?.type;
    if (value == null || type is! InterfaceType) continue;
    final library = type.element.library.uri;
    if (library.scheme == 'package' &&
        library.pathSegments.isNotEmpty &&
        library.pathSegments.first == package) {
      yield (type.element.displayName, value);
    }
  }
}

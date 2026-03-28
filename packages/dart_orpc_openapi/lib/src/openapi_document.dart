// ignore_for_file: invalid_use_of_protected_member

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:luthor/luthor.dart';

final class OpenApiSchemaComponent {
  const OpenApiSchemaComponent({required this.name, required this.validator});

  final String name;
  final Validator validator;
}

final class OpenApiSchemaRegistry {
  OpenApiSchemaRegistry(Iterable<OpenApiSchemaComponent> components)
    : _components = _indexComponents(components);

  final Map<String, OpenApiSchemaComponent> _components;

  Iterable<String> get names => _components.keys;

  Iterable<OpenApiSchemaComponent> get components => _components.values;

  OpenApiSchemaComponent? operator [](String name) => _components[name];

  static Map<String, OpenApiSchemaComponent> _indexComponents(
    Iterable<OpenApiSchemaComponent> components,
  ) {
    final indexed = <String, OpenApiSchemaComponent>{};

    for (final component in components) {
      if (indexed.containsKey(component.name)) {
        throw StateError(
          'Duplicate OpenAPI schema component "${component.name}".',
        );
      }

      indexed[component.name] = component;
    }

    return Map.unmodifiable(indexed);
  }
}

JsonObject createOpenApiDocument({
  required String title,
  String version = '1.0.0',
  String? description,
  required ProcedureMetadataRegistry procedures,
  OpenApiSchemaRegistry? schemas,
}) {
  final effectiveSchemas = schemas ?? OpenApiSchemaRegistry(const []);
  final paths = _buildPaths(procedures, effectiveSchemas);
  final componentSchemas = _buildComponentSchemas(effectiveSchemas);

  final info = <String, Object?>{'title': title, 'version': version};
  if (description != null && description.isNotEmpty) {
    info['description'] = description;
  }

  return <String, Object?>{
    'openapi': '3.0.3',
    'info': info,
    'paths': paths,
    'components': {'schemas': componentSchemas},
  };
}

String createScalarHtml({
  required String title,
  String openApiPath = '/openapi.json',
}) {
  final escapedTitle = _escapeHtmlText(title);
  final escapedPath = _escapeHtmlAttribute(openApiPath);

  return '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>$escapedTitle</title>
    <style>
      body {
        margin: 0;
        background: #f7f4ec;
      }
    </style>
  </head>
  <body>
    <script
      id="api-reference"
      data-url="$escapedPath"
      data-layout="modern"
      data-theme="default"
    ></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
</html>
''';
}

JsonObject _buildPaths(
  ProcedureMetadataRegistry procedures,
  OpenApiSchemaRegistry schemas,
) {
  final restProcedures =
      procedures.procedures
          .where((procedure) => procedure.path != null)
          .toList(growable: false)
        ..sort((left, right) {
          final leftPath = _toOpenApiPath(left.path!.path);
          final rightPath = _toOpenApiPath(right.path!.path);
          final pathCompare = leftPath.compareTo(rightPath);
          if (pathCompare != 0) {
            return pathCompare;
          }

          return left.path!.method.compareTo(right.path!.method);
        });

  final paths = <String, Object?>{};

  for (final procedure in restProcedures) {
    final path = _toOpenApiPath(procedure.path!.path);
    final pathItem =
        paths.putIfAbsent(path, () => <String, Object?>{})
            as Map<String, Object?>;
    pathItem[procedure.path!.method.toLowerCase()] = _buildOperation(
      procedure,
      schemas,
    );
  }

  return paths;
}

JsonObject _buildOperation(
  ProcedureMetadata procedure,
  OpenApiSchemaRegistry schemas,
) {
  final parameters = procedure.parameters
      .where(
        (parameter) =>
            parameter.source == ProcedureParameterSourceKind.path ||
            parameter.source == ProcedureParameterSourceKind.query ||
            parameter.source == ProcedureParameterSourceKind.header,
      )
      .map((parameter) => _buildParameter(parameter, procedure, schemas))
      .toList(growable: false);

  final operation = <String, Object?>{
    'operationId': procedure.rpcMethod,
    'tags': procedure.tags.isNotEmpty
        ? procedure.tags
        : [procedure.controllerNamespace],
    'responses': {
      '200': {
        'description': 'Successful response.',
        'content': {
          'application/json': {
            'schema': _schemaForTypeCode(procedure.outputTypeCode, schemas),
          },
        },
      },
      'default': {
        'description': 'Error response.',
        'content': {
          'application/json': {'schema': _schemaRef('RpcErrorResponse')},
        },
      },
    },
  };

  if (procedure.description != null && procedure.description!.isNotEmpty) {
    operation['description'] = procedure.description;
  }

  if (parameters.isNotEmpty) {
    operation['parameters'] = parameters;
  }

  final bodyParameter = procedure.parameters
      .where(
        (parameter) => parameter.source == ProcedureParameterSourceKind.body,
      )
      .firstOrNull;
  if (bodyParameter != null) {
    final requestBodySchema = _requestBodySchema(
      procedure,
      bodyParameter,
      schemas,
    );
    operation['requestBody'] = {
      'required': _isRequestBodyRequired(
        bodyParameter: bodyParameter,
        schema: requestBodySchema,
      ),
      'content': {
        'application/json': {'schema': requestBodySchema},
      },
    };
  }

  return operation;
}

JsonObject _buildParameter(
  ProcedureParameterMetadata parameter,
  ProcedureMetadata procedure,
  OpenApiSchemaRegistry schemas,
) {
  final location = switch (parameter.source) {
    ProcedureParameterSourceKind.path => 'path',
    ProcedureParameterSourceKind.query => 'query',
    ProcedureParameterSourceKind.header => 'header',
    ProcedureParameterSourceKind.rpcInput => 'query',
    ProcedureParameterSourceKind.body => 'query',
  };

  return <String, Object?>{
    'name': parameter.wireName,
    'in': location,
    'required': parameter.source == ProcedureParameterSourceKind.path
        ? true
        : !_isNullableTypeCode(parameter.typeCode),
    'schema': _schemaForTypeCode(parameter.typeCode, schemas),
    'x-rpc-parameter': parameter.parameterName,
    'x-rpc-method': procedure.rpcMethod,
  };
}

JsonObject _buildComponentSchemas(OpenApiSchemaRegistry schemas) {
  final componentSchemas = <String, Object?>{
    'RpcErrorBody': {
      'type': 'object',
      'required': ['code', 'message'],
      'properties': {
        'code': {'type': 'string'},
        'message': {'type': 'string'},
      },
    },
    'RpcErrorResponse': {
      'type': 'object',
      'required': ['error'],
      'properties': {'error': _schemaRef('RpcErrorBody')},
    },
  };

  final sortedComponents = schemas.components.toList(growable: false)
    ..sort((left, right) => left.name.compareTo(right.name));

  for (final component in sortedComponents) {
    componentSchemas[component.name] = _schemaForValidator(
      component.validator,
      schemas,
      currentComponentName: component.name,
      allowInlineCurrentComponent: true,
    );
  }

  return componentSchemas;
}

JsonObject _requestBodySchema(
  ProcedureMetadata procedure,
  ProcedureParameterMetadata bodyParameter,
  OpenApiSchemaRegistry schemas,
) {
  final externalDtoFields = procedure.parameters
      .where(
        (parameter) => parameter.source != ProcedureParameterSourceKind.body,
      )
      .map((parameter) => parameter.parameterName)
      .toList(growable: false);
  final schemaComponent = schemas[_nonNullableTypeCode(bodyParameter.typeCode)];

  if (schemaComponent == null ||
      procedure.inputTypeCode == null ||
      _nonNullableTypeCode(bodyParameter.typeCode) !=
          _nonNullableTypeCode(procedure.inputTypeCode!) ||
      externalDtoFields.isEmpty) {
    return _schemaForTypeCode(bodyParameter.typeCode, schemas);
  }

  final inlineSchema = _schemaForValidator(
    schemaComponent.validator,
    schemas,
    currentComponentName: schemaComponent.name,
    allowInlineCurrentComponent: true,
  );

  return _withoutObjectProperties(inlineSchema, externalDtoFields);
}

JsonObject _schemaForTypeCode(String typeCode, OpenApiSchemaRegistry schemas) {
  final nonNullableTypeCode = _nonNullableTypeCode(typeCode);

  if (schemas[nonNullableTypeCode] case final component?) {
    return _schemaRef(component.name);
  }

  if (nonNullableTypeCode == 'String') {
    return {'type': 'string'};
  }

  if (nonNullableTypeCode == 'int') {
    return {'type': 'integer'};
  }

  if (nonNullableTypeCode == 'double' || nonNullableTypeCode == 'num') {
    return {'type': 'number'};
  }

  if (nonNullableTypeCode == 'bool') {
    return {'type': 'boolean'};
  }

  if (nonNullableTypeCode == 'JsonObject' ||
      nonNullableTypeCode.startsWith('Map<')) {
    return {'type': 'object'};
  }

  if (nonNullableTypeCode.startsWith('List<')) {
    return {'type': 'array', 'items': {}};
  }

  return {'type': 'object'};
}

JsonObject _schemaForValidator(
  Validator validator,
  OpenApiSchemaRegistry schemas, {
  String? currentComponentName,
  bool allowInlineCurrentComponent = false,
}) {
  final componentName = validator.name;
  if (componentName != null && schemas[componentName] != null) {
    final shouldInlineCurrent =
        allowInlineCurrentComponent && componentName == currentComponentName;
    if (!shouldInlineCurrent) {
      return _schemaRef(componentName);
    }
  }

  if (validator.schemaValidation case final schemaValidation?) {
    return _schemaForObjectValidator(
      validator,
      schemaValidation,
      schemas,
      currentComponentName: currentComponentName,
    );
  }

  final listValidation = validator.validations
      .whereType<ListValidation>()
      .lastOrNull;
  if (listValidation != null) {
    return _schemaForListValidation(
      listValidation,
      schemas,
      currentComponentName: currentComponentName,
    );
  }

  final mapValidation = validator.validations
      .whereType<MapValidation>()
      .lastOrNull;
  if (mapValidation != null) {
    return _schemaForMapValidation(
      mapValidation,
      schemas,
      currentComponentName: currentComponentName,
    );
  }

  final schema = <String, Object?>{};

  if (validator.validations.any(
    (validation) => validation is StringValidation,
  )) {
    schema['type'] = 'string';
  } else if (validator.validations.any(
    (validation) => validation is IntValidation,
  )) {
    schema['type'] = 'integer';
  } else if (validator.validations.any(
    (validation) =>
        validation is DoubleValidation || validation is NumberValidation,
  )) {
    schema['type'] = 'number';
  } else if (validator.validations.any(
    (validation) => validation is BoolValidation,
  )) {
    schema['type'] = 'boolean';
  }

  for (final validation in validator.validations) {
    switch (validation) {
      case StringMinValidation(minLength: final minLength):
        schema['minLength'] = minLength;
      case StringMaxValidation(maxLength: final maxLength):
        schema['maxLength'] = maxLength;
      case StringLengthValidation(length: final length):
        schema['minLength'] = length;
        schema['maxLength'] = length;
      case StringEmailValidation():
        schema['format'] = 'email';
      case StringDateTimeValidation():
        schema['format'] = 'date-time';
      case StringUriValidation():
        schema['format'] = 'uri';
      case StringUuidValidation():
        schema['format'] = 'uuid';
      case StringRegexValidation(pattern: final pattern):
        schema['pattern'] = pattern;
      case NumberMinValidation(minValue: final minValue):
        schema['minimum'] = minValue;
      case NumberMaxValidation(maxValue: final maxValue):
        schema['maximum'] = maxValue;
      default:
        break;
    }
  }

  if (schema.isEmpty) {
    return {'type': 'object'};
  }

  return schema;
}

JsonObject _schemaForObjectValidator(
  Validator validator,
  SchemaValidation schemaValidation,
  OpenApiSchemaRegistry schemas, {
  String? currentComponentName,
}) {
  final properties = <String, Object?>{};
  final required = <String>[];
  final keys = schemaValidation.validatorSchema.keys.toList(growable: false)
    ..sort();

  for (final key in keys) {
    final fieldValidator = schemaValidation.validatorSchema[key]!.resolve();
    properties[key] = _schemaForValidator(
      fieldValidator,
      schemas,
      currentComponentName: currentComponentName,
    );

    if (fieldValidator.hasRequiredValidation) {
      required.add(key);
    }
  }

  final schema = <String, Object?>{'type': 'object', 'properties': properties};
  if (required.isNotEmpty) {
    schema['required'] = required;
  }
  if (validator.name != null && validator.name != currentComponentName) {
    schema['title'] = validator.name;
  }

  return schema;
}

JsonObject _schemaForListValidation(
  ListValidation validation,
  OpenApiSchemaRegistry schemas, {
  String? currentComponentName,
}) {
  final validators = validation.validators;
  if (validators == null || validators.isEmpty) {
    return {'type': 'array', 'items': {}};
  }

  final itemSchemas = validators
      .map(
        (validator) => _schemaForValidator(
          validator.resolve(),
          schemas,
          currentComponentName: currentComponentName,
        ),
      )
      .toList(growable: false);

  return {
    'type': 'array',
    'items': itemSchemas.length == 1
        ? itemSchemas.single
        : {'oneOf': itemSchemas},
  };
}

JsonObject _schemaForMapValidation(
  MapValidation validation,
  OpenApiSchemaRegistry schemas, {
  String? currentComponentName,
}) {
  final valueValidator = validation.valueValidator?.resolve();

  return {
    'type': 'object',
    if (valueValidator != null)
      'additionalProperties': _schemaForValidator(
        valueValidator,
        schemas,
        currentComponentName: currentComponentName,
      ),
  };
}

JsonObject _schemaRef(String componentName) {
  return {'\$ref': '#/components/schemas/$componentName'};
}

bool _isRequestBodyRequired({
  required ProcedureParameterMetadata bodyParameter,
  required JsonObject schema,
}) {
  if (_isNullableTypeCode(bodyParameter.typeCode)) {
    return false;
  }

  final requiredFields = schema['required'] is List<Object?>
      ? (schema['required'] as List<Object?>).whereType<String>().toList()
      : const <String>[];

  if (schema['type'] == 'object') {
    return requiredFields.isNotEmpty;
  }

  return true;
}

JsonObject _withoutObjectProperties(
  JsonObject schema,
  List<String> propertyNames,
) {
  final propertyNameSet = propertyNames.toSet();
  if (schema['type'] != 'object') {
    return schema;
  }

  final stripped = Map<String, Object?>.from(schema);
  final properties = stripped['properties'] is Map<String, Object?>
      ? Map<String, Object?>.from(
          stripped['properties'] as Map<String, Object?>,
        )
      : <String, Object?>{};
  for (final propertyName in propertyNameSet) {
    properties.remove(propertyName);
  }
  stripped['properties'] = properties;

  final requiredValues = stripped['required'] is List<Object?>
      ? List<Object?>.from(stripped['required'] as List<Object?>)
      : <Object?>[];
  final required = requiredValues
      .whereType<String>()
      .where((propertyName) => !propertyNameSet.contains(propertyName))
      .toList(growable: false);
  if (required.isNotEmpty) {
    stripped['required'] = required;
  } else {
    stripped.remove('required');
  }

  return stripped;
}

String _toOpenApiPath(String path) {
  return path.replaceAllMapped(
    RegExp(r':([A-Za-z_][A-Za-z0-9_]*)'),
    (match) => '{${match.group(1)!}}',
  );
}

String _nonNullableTypeCode(String typeCode) {
  if (typeCode.endsWith('?')) {
    return typeCode.substring(0, typeCode.length - 1);
  }

  return typeCode;
}

bool _isNullableTypeCode(String typeCode) => typeCode.endsWith('?');

String _escapeHtmlText(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _escapeHtmlAttribute(String value) {
  return _escapeHtmlText(
    value,
  ).replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }

    return first;
  }

  T? get lastOrNull {
    if (isEmpty) {
      return null;
    }

    return last;
  }
}

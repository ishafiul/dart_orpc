import 'package:dart_orpc_core/dart_orpc_core.dart';

final class OpenApiServer {
  const OpenApiServer({required this.url, this.description});

  final String url;
  final String? description;

  JsonObject toJson() {
    final json = <String, Object?>{'url': url};
    if (description != null && description!.isNotEmpty) {
      json['description'] = description;
    }
    return json;
  }
}

final class OpenApiDocumentOptions {
  const OpenApiDocumentOptions({
    this.title,
    this.version = '1.0.0',
    this.description,
    this.servers = const [],
  });

  final String? title;
  final String version;
  final String? description;
  final List<OpenApiServer> servers;
}

JsonObject createOpenApiDocument({
  required String title,
  String version = '1.0.0',
  String? description,
  Iterable<OpenApiServer> servers = const [],
  required ProcedureMetadataRegistry procedures,
  DtoSchemaRegistry? schemas,
}) {
  final effectiveSchemas = schemas ?? DtoSchemaRegistry(const []);
  final paths = _buildPaths(procedures, effectiveSchemas);
  final componentSchemas = _buildComponentSchemas(effectiveSchemas);
  final serverList = servers.toList(growable: false);
  final securitySchemes = _buildSecuritySchemes(procedures);

  final info = <String, Object?>{'title': title, 'version': version};
  if (description != null && description.isNotEmpty) {
    info['description'] = description;
  }

  final document = <String, Object?>{
    'openapi': '3.0.3',
    'info': info,
    'paths': paths,
    'components': {
      'schemas': componentSchemas,
      if (securitySchemes.isNotEmpty) 'securitySchemes': securitySchemes,
    },
  };

  if (serverList.isNotEmpty) {
    document['servers'] = [for (final server in serverList) server.toJson()];
  }

  return document;
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
  DtoSchemaRegistry schemas,
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
    final pathItem = paths.putIfAbsent(
      path,
      () => <String, Object?>{},
    ) as Map<String, Object?>;
    pathItem[procedure.path!.method.toLowerCase()] = _buildOperation(
      procedure,
      schemas,
    );
  }

  return paths;
}

JsonObject _buildOperation(
  ProcedureMetadata procedure,
  DtoSchemaRegistry schemas,
) {
  final isSse = procedure.path?.responseKind == RestResponseKind.sse;
  final parameters = procedure.parameters
      .where(
        (parameter) =>
            parameter.source == ProcedureParameterSourceKind.path ||
            parameter.source == ProcedureParameterSourceKind.query ||
            parameter.source == ProcedureParameterSourceKind.header,
      )
      .map((parameter) => _buildParameter(parameter, procedure, schemas))
      .toList(growable: false);

  final successStatus =
      procedure.path?.statusCode ??
      (procedure.outputTypeCode == 'void' ? 204 : 200);
  final noContent =
      procedure.outputTypeCode == 'void' ||
      successStatus == 204 ||
      successStatus == 304;
  final responseHeaders = procedure.path?.headers ?? const <String, String>{};
  final operation = <String, Object?>{
    'operationId': procedure.rpcMethod,
    'tags': procedure.tags.isNotEmpty
        ? procedure.tags
        : [procedure.controllerNamespace],
    'responses': {
      '$successStatus': {
        'description': noContent
            ? 'Successful response with no content.'
            : 'Successful response.',
        if (responseHeaders.isNotEmpty)
          'headers': {
            for (final entry in responseHeaders.entries)
              entry.key: {
                'schema': {'type': 'string'},
                'example': entry.value,
              },
          },
        if (!noContent)
          'content': {
            if (isSse)
              'text/event-stream': {
                'schema': {'type': 'string'},
              }
            else
              'application/json': {
                'schema': _schemaForTypeCode(procedure.outputTypeCode, schemas),
              },
          },
      },
      for (final code in RpcErrorCode.values)
        if (code.statusCode != successStatus)
          '${code.statusCode}': {
            'description': code.wireName,
            'content': {
              'application/json': {'schema': _schemaRef('RpcErrorResponse')},
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

  if (isSse) {
    operation['x-dart-orpc-stream'] = {
      'kind': 'server-stream',
      'eventSchema': _schemaForTypeCode(procedure.outputTypeCode, schemas),
      'terminalEvents': {
        'complete': 'dart-orpc-complete',
        'error': 'dart-orpc-error',
      },
    };
  }

  if (procedure.description != null && procedure.description!.isNotEmpty) {
    operation['description'] = procedure.description;
  }

  if (procedure.securityRequirements.isNotEmpty) {
    operation['security'] = [
      {
        for (final requirement in procedure.securityRequirements)
          requirement.schemeName: <String>[],
      },
    ];
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

JsonObject _buildSecuritySchemes(ProcedureMetadataRegistry procedures) {
  final schemeNames = <String>{
    for (final procedure in procedures.procedures)
      for (final requirement in procedure.securityRequirements)
        requirement.schemeName,
  }.toList()..sort();

  return {
    for (final schemeName in schemeNames)
      if (schemeName == 'bearerAuth')
        schemeName: {'type': 'http', 'scheme': 'bearer', 'bearerFormat': 'JWT'},
  };
}

JsonObject _buildParameter(
  ProcedureParameterMetadata parameter,
  ProcedureMetadata procedure,
  DtoSchemaRegistry schemas,
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

JsonObject _buildComponentSchemas(DtoSchemaRegistry schemas) {
  final componentSchemas = <String, Object?>{
    'RpcErrorBody': {
      'type': 'object',
      'required': ['code', 'message'],
      'properties': {
        'code': {'type': 'string'},
        'message': {'type': 'string'},
        'details': {
          'type': 'object',
          'additionalProperties': true,
          'description':
              'Optional structured context for the error. Omitted when '
              'there is none. The `issues` key is reserved for framework '
              'validation issues.',
        },
      },
    },
    'RpcErrorResponse': {
      'type': 'object',
      'required': ['error'],
      'properties': {'error': _schemaRef('RpcErrorBody')},
    },
  };

  final sortedSchemas = schemas.schemas.toList(growable: false)
    ..sort((left, right) => left.name.compareTo(right.name));

  for (final schema in sortedSchemas) {
    componentSchemas[schema.name] = _schemaForDto(schema);
  }

  return componentSchemas;
}

JsonObject _requestBodySchema(
  ProcedureMetadata procedure,
  ProcedureParameterMetadata bodyParameter,
  DtoSchemaRegistry schemas,
) {
  final externalDtoFields = procedure.parameters
      .where(
        (parameter) => parameter.source != ProcedureParameterSourceKind.body,
      )
      .map((parameter) => parameter.parameterName)
      .toList(growable: false);
  final schema = schemas[_nonNullableTypeCode(bodyParameter.typeCode)];

  if (schema == null ||
      procedure.inputTypeCode == null ||
      _nonNullableTypeCode(bodyParameter.typeCode) !=
          _nonNullableTypeCode(procedure.inputTypeCode!) ||
      externalDtoFields.isEmpty) {
    return _schemaForTypeCode(bodyParameter.typeCode, schemas);
  }

  return _withoutObjectProperties(_schemaForDto(schema), externalDtoFields);
}

JsonObject _schemaForTypeCode(String typeCode, DtoSchemaRegistry schemas) {
  final nonNullableTypeCode = _nonNullableTypeCode(typeCode);

  if (schemas[nonNullableTypeCode] case final schema?) {
    return _schemaRef(schema.name);
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

/// The JSON Schema object for [schema]: properties in wire-name order and
/// the required wire names, also sorted.
JsonObject _schemaForDto(DtoSchemaMetadata schema) {
  final fields = schema.fields.toList(growable: false)
    ..sort((left, right) => left.wireName.compareTo(right.wireName));
  final required = [
    for (final field in fields)
      if (field.required) field.wireName,
  ];
  return {
    'type': 'object',
    'properties': {
      for (final field in fields) field.wireName: _schemaForField(field),
    },
    if (required.isNotEmpty) 'required': required,
  };
}

JsonObject _schemaForField(DtoFieldMetadata field) {
  final schema = {
    ..._schemaForType(field.type),
    ..._schemaForConstraints(field.type, field.constraints),
  };
  if (field.customValidation) {
    schema['x-dart-orpc-custom-validation'] = true;
  }
  return schema;
}

JsonObject _schemaForType(DtoFieldType type) => switch (type) {
  DtoStringType() => {'type': 'string'},
  DtoIntegerType() => {'type': 'integer'},
  DtoNumberType() => {'type': 'number'},
  DtoBooleanType() => {'type': 'boolean'},
  DtoAnyType() => <String, Object?>{},
  DtoObjectType(:final component) => _schemaRef(component),
  DtoListType(:final element) => {
    'type': 'array',
    'items': _schemaForType(element),
  },
  DtoMapType(:final value) => {
    'type': 'object',
    'additionalProperties': _schemaForType(value),
  },
  DtoEnumType(:final values) => {
    if (_enumType(values) case final type?) 'type': type,
    'enum': values,
  },
};

/// The JSON type shared by every enum value, if there is one.
String? _enumType(List<Object> values) {
  if (values.every((value) => value is String)) return 'string';
  if (values.every((value) => value is int)) return 'integer';
  if (values.every((value) => value is num)) return 'number';
  if (values.every((value) => value is bool)) return 'boolean';
  return null;
}

JsonObject _schemaForConstraints(
  DtoFieldType type,
  DtoFieldConstraints constraints,
) {
  final (minKey, maxKey) = switch (type) {
    DtoStringType() => ('minLength', 'maxLength'),
    DtoListType() => ('minItems', 'maxItems'),
    DtoIntegerType() || DtoNumberType() => ('minimum', 'maximum'),
    _ => (null, null),
  };
  final schema = <String, Object?>{};
  if (minKey != null && maxKey != null) {
    if (constraints.min case final min?) schema[minKey] = min;
    if (constraints.max case final max?) schema[maxKey] = max;
    if (constraints.length case final length?
        when type is DtoStringType || type is DtoListType) {
      schema[minKey] = length;
      schema[maxKey] = length;
    }
  }
  if (constraints.pattern case final pattern?) schema['pattern'] = pattern;
  if (constraints.format case final format?) {
    schema['format'] = switch (format) {
      DtoStringFormat.email => 'email',
      DtoStringFormat.dateTime => 'date-time',
      DtoStringFormat.uri => 'uri',
      DtoStringFormat.uuid => 'uuid',
    };
  }
  return schema;
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
  return _escapeHtmlText(value)
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

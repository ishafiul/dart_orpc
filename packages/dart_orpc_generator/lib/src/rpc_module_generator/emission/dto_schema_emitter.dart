part of '../../rpc_module_generator.dart';

void _writeDtoSchemaSections(
  StringBuffer buffer,
  _ModuleGenerationPlan context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln(
      'DtoSchemaRegistry ${names.createLocalDtoSchemaRegistryName}() {',
    );
  if (context.dtoSchemas.isEmpty) {
    buffer.writeln('  return DtoSchemaRegistry(const []);');
  } else {
    buffer.writeln('  return DtoSchemaRegistry(const [');
    for (final schema in context.dtoSchemas) {
      buffer.writeln('${_dtoSchemaLiteral(schema)},');
    }
    buffer.writeln('  ]);');
  }
  buffer
    ..writeln('}')
    ..writeln()
    ..writeln('DtoSchemaRegistry ${names.createDtoSchemaRegistryName}() {')
    ..writeln('  return DtoSchemaRegistry([');
  for (final importedModule in context.rootModule.importedModules) {
    buffer.writeln(
      '    ...${_publicDtoSchemaRegistryFactoryNameFor(importedModule.displayName)}().schemas,',
    );
  }
  buffer
    ..writeln('    ...${names.createLocalDtoSchemaRegistryName}().schemas,')
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'DtoSchemaRegistry ${names.composeDtoSchemaRegistryName}() => ${names.createDtoSchemaRegistryName}();',
    );
}

String _dtoSchemaLiteral(DtoSchemaMetadata schema) {
  final buffer = StringBuffer()
    ..writeln('    DtoSchemaMetadata(')
    ..writeln("      name: '${_escapeDartString(schema.name)}',");
  if (schema.fields.isEmpty) {
    buffer.writeln('      fields: [],');
  } else {
    buffer.writeln('      fields: [');
    for (final field in schema.fields) {
      buffer.writeln('        ${_dtoFieldLiteral(field)},');
    }
    buffer.writeln('      ],');
  }
  buffer.write('    )');
  return buffer.toString();
}

/// Only non-default properties are written, so the output stays readable.
String _dtoFieldLiteral(DtoFieldMetadata field) {
  final arguments = [
    "wireName: '${_escapeDartString(field.wireName)}'",
    'type: ${_dtoTypeLiteral(field.type)}',
    if (field.nullable) 'nullable: true',
    if (!field.required) 'required: false',
    if (!field.constraints.isEmpty)
      'constraints: ${_dtoConstraintsLiteral(field.constraints)}',
    if (field.customValidation) 'customValidation: true',
  ];
  return 'DtoFieldMetadata(${arguments.join(', ')})';
}

String _dtoTypeLiteral(DtoFieldType type) => switch (type) {
  DtoStringType() => 'DtoStringType()',
  DtoIntegerType() => 'DtoIntegerType()',
  DtoNumberType() => 'DtoNumberType()',
  DtoBooleanType() => 'DtoBooleanType()',
  DtoAnyType() => 'DtoAnyType()',
  DtoObjectType(:final component) =>
    "DtoObjectType('${_escapeDartString(component)}')",
  DtoListType(:final element, :final elementNullable) =>
    'DtoListType(${_dtoTypeLiteral(element)}'
        '${elementNullable ? ', elementNullable: true' : ''})',
  DtoMapType(:final value, :final valueNullable) =>
    'DtoMapType(${_dtoTypeLiteral(value)}'
        '${valueNullable ? ', valueNullable: true' : ''})',
  DtoEnumType(:final values) =>
    'DtoEnumType([${values.map(_dtoValueLiteral).join(', ')}])',
};

String _dtoConstraintsLiteral(DtoFieldConstraints constraints) {
  final arguments = [
    if (constraints.min case final min?) 'min: $min',
    if (constraints.max case final max?) 'max: $max',
    if (constraints.length case final length?) 'length: $length',
    if (constraints.pattern case final pattern?)
      "pattern: '${_escapeDartString(pattern)}'",
    if (constraints.format case final format?)
      'format: DtoStringFormat.${format.name}',
  ];
  return 'DtoFieldConstraints(${arguments.join(', ')})';
}

String _dtoValueLiteral(Object value) =>
    value is String ? "'${_escapeDartString(value)}'" : '$value';

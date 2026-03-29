part of '../rpc_module_generator.dart';

void _writeOpenApiSections(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('OpenApiSchemaRegistry ${names.createLocalOpenApiSchemaRegistryName}() {')
    ..writeln('  return OpenApiSchemaRegistry([');
  for (final component in context.openApiSchemaComponents) {
    buffer
      ..writeln('    OpenApiSchemaComponent(')
      ..writeln("      name: '${component.name}',")
      ..writeln('      validator: ${component.validatorExpression},')
      ..writeln('    ),');
  }
  buffer
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln('OpenApiSchemaRegistry ${names.createOpenApiSchemaRegistryName}() {')
    ..writeln('  return OpenApiSchemaRegistry([');
  for (final importedModule in context.rootModule.importedModules) {
    buffer.writeln(
      '    ...${_publicOpenApiSchemaRegistryFactoryNameFor(importedModule.displayName)}().components,',
    );
  }
  buffer
    ..writeln('    ...${names.createLocalOpenApiSchemaRegistryName}().components,')
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln('OpenApiSchemaRegistry ${names.composeOpenApiSchemaRegistryName}() => ${names.createOpenApiSchemaRegistryName}();')
    ..writeln()
    ..writeln('JsonObject ${names.createOpenApiDocumentName}() {')
    ..writeln('  return createOpenApiDocument(')
    ..writeln("    title: '${_escapeDartString(context.openApiTitle)}',")
    ..writeln('    procedures: ${names.createMetadataRegistryName}(),')
    ..writeln('    schemas: ${names.createOpenApiSchemaRegistryName}(),')
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln('JsonObject ${names.composeOpenApiDocumentName}() => ${names.createOpenApiDocumentName}();')
    ..writeln()
    ..writeln('// ignore: unused_element')
    ..writeln('RpcHttpApp ${names.buildAppName}() {')
    ..writeln("  return RpcHttpApp(procedures: ${names.createRegistryName}(), restRoutes: ${names.createRestRouteRegistryName}(), openApiDocument: ${names.createOpenApiDocumentName}(), docsHtml: createScalarHtml(title: '${_escapeDartString(context.openApiTitle)}'));")
    ..writeln('}')
    ..writeln()
    ..writeln('RpcHttpApp ${names.composeBuildAppName}() => ${names.buildAppName}();');
}

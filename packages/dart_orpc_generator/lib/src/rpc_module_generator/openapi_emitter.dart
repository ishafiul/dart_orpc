part of '../rpc_module_generator.dart';

void _writeOpenApiSections(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln(
      'OpenApiSchemaRegistry ${names.createLocalOpenApiSchemaRegistryName}() {',
    )
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
    ..writeln(
      'OpenApiSchemaRegistry ${names.createOpenApiSchemaRegistryName}() {',
    )
    ..writeln('  return OpenApiSchemaRegistry([');
  for (final importedModule in context.rootModule.importedModules) {
    buffer.writeln(
      '    ...${_publicOpenApiSchemaRegistryFactoryNameFor(importedModule.displayName)}().components,',
    );
  }
  buffer
    ..writeln(
      '    ...${names.createLocalOpenApiSchemaRegistryName}().components,',
    )
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'OpenApiSchemaRegistry ${names.composeOpenApiSchemaRegistryName}() => ${names.createOpenApiSchemaRegistryName}();',
    )
    ..writeln()
    ..writeln(
      'JsonObject ${names.createOpenApiDocumentName}({OpenApiDocumentOptions? options}) {',
    )
    ..writeln(
      '  final effectiveOptions = options ?? const OpenApiDocumentOptions();',
    )
    ..writeln('  return createOpenApiDocument(')
    ..writeln(
      "    title: effectiveOptions.title ?? '${_escapeDartString(context.openApiTitle)}',",
    )
    ..writeln('    version: effectiveOptions.version,')
    ..writeln('    description: effectiveOptions.description,')
    ..writeln('    servers: effectiveOptions.servers,')
    ..writeln('    procedures: ${names.createMetadataRegistryName}(),')
    ..writeln('    schemas: ${names.createOpenApiSchemaRegistryName}(),')
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'JsonObject ${names.composeOpenApiDocumentName}({OpenApiDocumentOptions? options}) => ${names.createOpenApiDocumentName}(options: options);',
    )
    ..writeln()
    ..writeln('// ignore: unused_element')
    ..writeln(
      'RpcHttpApp ${names.buildAppName}({OpenApiDocumentOptions? openApi, RpcHttpDocsOptions? docs, Iterable<RpcHttpMiddleware> middleware = const []}) {',
    )
    ..writeln(
      '  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();',
    )
    ..writeln('  final effectiveDocs = docs ?? const RpcHttpDocsOptions();')
    ..writeln(
      "  final effectiveOpenApiTitle = effectiveOpenApi.title ?? '${_escapeDartString(context.openApiTitle)}';",
    )
    ..writeln('  final effectiveOpenApiPath = effectiveDocs.openApiPath;')
    ..writeln('  return RpcHttpApp(')
    ..writeln('    procedures: ${names.createRegistryName}(),')
    ..writeln('    restRoutes: ${names.createRestRouteRegistryName}(),')
    ..writeln(
      '    openApiDocument: ${names.createOpenApiDocumentName}(options: effectiveOpenApi),',
    )
    ..writeln('    openApiPath: effectiveOpenApiPath,')
    ..writeln(
      '    docsHtml: effectiveDocs.html ?? createScalarHtml(title: effectiveDocs.title ?? effectiveOpenApiTitle, openApiPath: effectiveOpenApiPath),',
    )
    ..writeln('    docsPath: effectiveDocs.docsPath,')
    ..writeln('    docsBasicAuth: effectiveDocs.basicAuth,')
    ..writeln('    middleware: middleware,')
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'RpcHttpApp ${names.composeBuildAppName}({OpenApiDocumentOptions? openApi, RpcHttpDocsOptions? docs, Iterable<RpcHttpMiddleware> middleware = const []}) => ${names.buildAppName}(openApi: openApi, docs: docs, middleware: middleware);',
    );
}

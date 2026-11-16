part of '../../rpc_module_generator.dart';

void _writeOpenApiSections(StringBuffer buffer, _ModuleGenerationPlan context) {
  final names = context.generatedNames;
  buffer
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
    ..writeln('    schemas: ${names.createDtoSchemaRegistryName}(),')
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'JsonObject ${names.composeOpenApiDocumentName}({OpenApiDocumentOptions? options}) => ${names.createOpenApiDocumentName}(options: options);',
    )
    ..writeln()
    ..writeln(
      'RpcHttpApp ${names.buildAppName}(${_buildAppParameterBlock(context)}) {',
    )
    ..writeln(
      '  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();',
    )
    ..writeln('  final effectiveDocs = docs ?? const RpcHttpDocsOptions();')
    ..writeln(
      "  final effectiveOpenApiTitle = effectiveOpenApi.title ?? '${_escapeDartString(context.openApiTitle)}';",
    )
    ..writeln('  final effectiveOpenApiPath = effectiveDocs.openApiPath;')
    ..writeln(
      '  final container = ${names.createContainerName}(${_dependencyArgumentList(context)});',
    )
    ..writeln(
      '  final procedures = ${names.createRegistryFromContainerName}(container);',
    )
    ..writeln(
      '  final restRoutes = ${names.createRestRouteRegistryFromContainerName}(container);',
    )
    ..writeln('  return RpcHttpApp(')
    ..writeln('    procedures: procedures,')
    ..writeln('    restRoutes: restRoutes,')
    ..writeln('    onClose: container.dispose,')
    ..writeln(
      '    openApiDocument: ${names.createOpenApiDocumentName}(options: effectiveOpenApi),',
    )
    ..writeln('    openApiPath: effectiveOpenApiPath,')
    ..writeln(
      '    docsHtml: effectiveDocs.html ?? createScalarHtml(title: effectiveDocs.title ?? effectiveOpenApiTitle, openApiPath: effectiveOpenApiPath),',
    )
    ..writeln('    docsPath: effectiveDocs.docsPath,')
    ..writeln('    docsBasicAuth: effectiveDocs.basicAuth,')
    ..writeAll([
      for (final parameter in _buildAppParameters)
        if (parameter.passedToApp)
          '    ${parameter.name}: ${parameter.name},\n',
    ])
    ..writeln(
      '    upgradeHandlers: [if (webSocket != null) RpcWebSocketUpgradeHandler(procedures: procedures, options: webSocket)],',
    )
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'RpcHttpApp ${names.composeBuildAppName}(${_buildAppParameterBlock(context)}) => ${names.buildAppName}(${_buildAppForwardedArguments(context)});',
    );
}

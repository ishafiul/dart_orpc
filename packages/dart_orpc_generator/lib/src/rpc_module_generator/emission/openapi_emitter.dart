part of '../../rpc_module_generator.dart';

void _writeOpenApiSections(StringBuffer buffer, _ModuleGenerationPlan context) {
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
    ..writeln(
      'RpcHttpApp ${names.buildAppName}({${_dependencyParameterFields(context)}${_dependencyParameterFields(context).isEmpty ? '' : ', '}OpenApiDocumentOptions? openApi, RpcHttpDocsOptions? docs, RpcHttpStaticOptions? staticAssets, RpcHttpHealthOptions? health, RpcHttpMetricsOptions? metrics, RpcWebSocketServerOptions? webSocket, RpcContextBindings bindings = const RpcContextBindings.empty(), RpcContextFactory? contextFactory, Duration sseHeartbeatInterval = const Duration(seconds: 15), Iterable<RpcHttpMiddleware> middleware = const []}) {',
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
      '  final runtime = ${names.createRuntimeName}(${_dependencyArgumentList(context)});',
    )
    ..writeln('  return RpcHttpApp(')
    ..writeln('    procedures: runtime.procedures,')
    ..writeln('    restRoutes: runtime.restRoutes,')
    ..writeln(
      '    openApiDocument: ${names.createOpenApiDocumentName}(options: effectiveOpenApi),',
    )
    ..writeln('    openApiPath: effectiveOpenApiPath,')
    ..writeln(
      '    docsHtml: effectiveDocs.html ?? createScalarHtml(title: effectiveDocs.title ?? effectiveOpenApiTitle, openApiPath: effectiveOpenApiPath),',
    )
    ..writeln('    docsPath: effectiveDocs.docsPath,')
    ..writeln('    docsBasicAuth: effectiveDocs.basicAuth,')
    ..writeln('    staticAssets: staticAssets,')
    ..writeln('    health: health,')
    ..writeln('    metrics: metrics,')
    ..writeln('    bindings: bindings,')
    ..writeln('    contextFactory: contextFactory,')
    ..writeln('    sseHeartbeatInterval: sseHeartbeatInterval,')
    ..writeln(
      '    upgradeHandlers: [if (webSocket != null) RpcWebSocketUpgradeHandler(procedures: runtime.procedures, options: webSocket)],',
    )
    ..writeln('    middleware: middleware,')
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'RpcHttpApp ${names.composeBuildAppName}({${_dependencyParameterFields(context)}${_dependencyParameterFields(context).isEmpty ? '' : ', '}OpenApiDocumentOptions? openApi, RpcHttpDocsOptions? docs, RpcHttpStaticOptions? staticAssets, RpcHttpHealthOptions? health, RpcHttpMetricsOptions? metrics, RpcWebSocketServerOptions? webSocket, RpcContextFactory? contextFactory, RpcContextBindings bindings = const RpcContextBindings.empty(), Duration sseHeartbeatInterval = const Duration(seconds: 15), Iterable<RpcHttpMiddleware> middleware = const []}) => ${names.buildAppName}(${_dependencyArgumentList(context)}${_dependencyArgumentList(context).isEmpty ? '' : ', '}openApi: openApi, docs: docs, staticAssets: staticAssets, health: health, metrics: metrics, webSocket: webSocket, bindings: bindings, contextFactory: contextFactory, sseHeartbeatInterval: sseHeartbeatInterval, middleware: middleware);',
    );
}

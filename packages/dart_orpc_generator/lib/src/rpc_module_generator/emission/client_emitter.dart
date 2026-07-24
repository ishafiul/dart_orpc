part of '../../rpc_module_generator.dart';

void _writeClientSections(StringBuffer buffer, _ModuleGenerationPlan context) {
  _writeRootClient(buffer, context);
  _writeControllerClients(buffer, context);
  _writeGeneratedExtension(buffer, context);
}

void _writeRootClient(StringBuffer buffer, _ModuleGenerationPlan context) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('class ${names.rootClientName} {')
    ..writeln(
      '  ${names.rootClientName}({required RpcClientTransports transports}) : _transports = transports;',
    )
    ..writeln()
    ..writeln('  final RpcClientTransports _transports;');
  if (context.hasImportedRpcClientControllers ||
      context.composedRpcClientGetters.isNotEmpty) {
    buffer.writeln();
    for (final importedModule in context.importedModulesWithRpcClients) {
      final importedRootClientName = _rootClientNameFor(
        importedModule.displayName,
        reservedNames: {
          for (final controller in importedModule.rpcCompatibleControllers)
            controller.clientClassName,
        },
      );
      final importedClientFieldName =
          '_${_camelCase(importedModule.displayName)}Client';
      buffer.writeln(
        '  late final $importedRootClientName $importedClientFieldName = $importedRootClientName(transports: _transports);',
      );
    }
    for (final getter in context.composedRpcClientGetters) {
      buffer.writeln(
        '  late final ${getter.clientGetterName} = ${getter.initializerExpression};',
      );
    }
  }
  buffer.writeln('}');
}

void _writeControllerClients(
  StringBuffer buffer,
  _ModuleGenerationPlan context,
) {
  for (final controller in context.rpcClientControllers) {
    buffer
      ..writeln()
      ..writeln('class ${controller.clientClassName} {')
      ..writeln('  ${controller.clientClassName}(this._transports);')
      ..writeln()
      ..writeln('  final RpcClientTransports _transports;');
    for (final procedure in controller.rpcCompatibleProcedures) {
      _writeClientProcedure(buffer, procedure);
    }
    buffer.writeln('}');
  }
}

void _writeClientProcedure(StringBuffer buffer, _ResolvedProcedure procedure) {
  final decodeLine =
      '      decode: (json) => ${procedure.outputTypeCode}.fromJson(Map<String, dynamic>.from(expectJsonObject(json, context: \'RPC response for "${procedure.rpcMethod}"\'))),';
  final returnType = procedure.isStream ? 'Stream' : 'Future';
  final callerType = procedure.isStream ? 'RpcStreamCaller' : 'RpcCaller';
  final transportExpression = procedure.isStream
      ? "_transports.requireStreaming('${procedure.rpcMethod}')"
      : "_transports.requireUnary('${procedure.rpcMethod}')";
  final callerMethod = procedure.isStream ? 'call' : 'call';
  if (procedure.hasInput) {
    buffer
      ..writeln()
      ..writeln(
        '  $returnType<${procedure.outputTypeCode}> ${procedure.methodName}(${procedure.inputTypeCode!} ${procedure.inputParameterName!}) {',
      )
      ..writeln(
        '    return $callerType($transportExpression).$callerMethod<${procedure.outputTypeCode}>(',
      )
      ..writeln("      method: '${procedure.rpcMethod}',")
      ..writeln('      input: ${procedure.inputParameterName!}.toJson(),')
      ..writeln(decodeLine)
      ..writeln('    );')
      ..writeln('  }');
    return;
  }
  buffer
    ..writeln()
    ..writeln(
      '  $returnType<${procedure.outputTypeCode}> ${procedure.methodName}() {',
    )
    ..writeln(
      '    return $callerType($transportExpression).$callerMethod<${procedure.outputTypeCode}>(',
    )
    ..writeln("      method: '${procedure.rpcMethod}',")
    ..writeln(decodeLine)
    ..writeln('    );')
    ..writeln('  }');
}

void _writeGeneratedExtension(
  StringBuffer buffer,
  _ModuleGenerationPlan context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln(
      'extension DartOrpc${context.moduleName}Generated on ${context.moduleName} {',
    )
    ..writeln(
      '  RpcProcedureRegistry procedureRegistry() => ${names.composeProcedureRegistryName}();',
    )
    ..writeln(
      '  RestRouteRegistry restRouteRegistry() => ${names.composeRestRouteRegistryName}();',
    )
    ..writeln(
      '  ProcedureMetadataRegistry procedureMetadata() => ${names.composeMetadataRegistryName}();',
    )
    ..writeln(
      '  OpenApiSchemaRegistry openApiSchemaRegistry() => ${names.composeOpenApiSchemaRegistryName}();',
    )
    ..writeln(
      '  JsonObject openApiDocument({OpenApiDocumentOptions? options}) => ${names.composeOpenApiDocumentName}(options: options);',
    )
    ..writeln(
      '  RpcHttpApp buildRpcApp({OpenApiDocumentOptions? openApi, RpcHttpDocsOptions? docs, RpcHttpStaticOptions? staticAssets, RpcHttpHealthOptions? health, RpcHttpMetricsOptions? metrics, RpcWebSocketServerOptions? webSocket, RpcContextFactory? contextFactory, Duration sseHeartbeatInterval = const Duration(seconds: 15), Iterable<RpcHttpMiddleware> middleware = const []}) => ${names.composeBuildAppName}(openApi: openApi, docs: docs, staticAssets: staticAssets, health: health, metrics: metrics, webSocket: webSocket, contextFactory: contextFactory, sseHeartbeatInterval: sseHeartbeatInterval, middleware: middleware);',
    )
    ..writeln(
      '  ${names.rootClientName} createClient({required RpcClientTransports transports}) => ${names.rootClientName}(transports: transports);',
    )
    ..writeln('}');
}

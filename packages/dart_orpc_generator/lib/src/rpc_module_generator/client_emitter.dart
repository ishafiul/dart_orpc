part of '../rpc_module_generator.dart';

void _writeClientSections(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  _writeRootClient(buffer, context);
  _writeControllerClients(buffer, context);
  _writeGeneratedExtension(buffer, context);
}

void _writeRootClient(StringBuffer buffer, _ModuleGenerationContext context) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('class ${names.rootClientName} {');
  buffer.writeln(_rootClientConstructorLine(context));
  if (context.needsTransportField) {
    buffer
      ..writeln()
      ..writeln('  final RpcTransport _transport;');
  }
  if (context.hasLocalRpcClientControllers) {
    buffer
      ..writeln()
      ..writeln('  final RpcCaller _caller;');
  }
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
        '  late final $importedRootClientName $importedClientFieldName = $importedRootClientName(transport: _transport);',
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

String _rootClientConstructorLine(_ModuleGenerationContext context) {
  final names = context.generatedNames;
  if (context.hasLocalRpcClientControllers && context.needsTransportField) {
    return '  ${names.rootClientName}({required RpcTransport transport}) : _transport = transport, _caller = RpcCaller(transport);';
  }
  if (context.hasLocalRpcClientControllers) {
    return '  ${names.rootClientName}({required RpcTransport transport}) : _caller = RpcCaller(transport);';
  }
  if (context.needsTransportField) {
    return '  ${names.rootClientName}({required RpcTransport transport}) : _transport = transport;';
  }
  return '  ${names.rootClientName}({required RpcTransport transport});';
}

void _writeControllerClients(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  for (final controller in context.rpcClientControllers) {
    buffer
      ..writeln()
      ..writeln('class ${controller.clientClassName} {')
      ..writeln('  ${controller.clientClassName}(this._caller);')
      ..writeln()
      ..writeln('  final RpcCaller _caller;');
    for (final procedure in controller.rpcCompatibleProcedures) {
      _writeClientProcedure(buffer, procedure);
    }
    buffer.writeln('}');
  }
}

void _writeClientProcedure(StringBuffer buffer, _ResolvedProcedure procedure) {
  final decodeLine =
      '      decode: (json) => ${procedure.outputTypeCode}.fromJson(Map<String, dynamic>.from(expectJsonObject(json, context: \'RPC response for "${procedure.rpcMethod}"\'))),';
  if (procedure.hasInput) {
    buffer
      ..writeln()
      ..writeln(
        '  Future<${procedure.outputTypeCode}> ${procedure.methodName}(${procedure.inputTypeCode!} ${procedure.inputParameterName!}) {',
      )
      ..writeln('    return _caller.call<${procedure.outputTypeCode}>(')
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
      '  Future<${procedure.outputTypeCode}> ${procedure.methodName}() {',
    )
    ..writeln('    return _caller.call<${procedure.outputTypeCode}>(')
    ..writeln("      method: '${procedure.rpcMethod}',")
    ..writeln(decodeLine)
    ..writeln('    );')
    ..writeln('  }');
}

void _writeGeneratedExtension(
  StringBuffer buffer,
  _ModuleGenerationContext context,
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
      '  RpcHttpApp buildRpcApp({OpenApiDocumentOptions? openApi, RpcHttpDocsOptions? docs, Iterable<RpcHttpMiddleware> middleware = const []}) => ${names.composeBuildAppName}(openApi: openApi, docs: docs, middleware: middleware);',
    )
    ..writeln(
      '  ${names.rootClientName} createClient({required RpcTransport transport}) => ${names.rootClientName}(transport: transport);',
    )
    ..writeln('}');
}

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
    for (final procedure in controller.rpcCompatibleProcedures) {
      _writeClientRequestOptions(buffer, procedure);
    }
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

void _writeClientRequestOptions(
  StringBuffer buffer,
  _ResolvedProcedure procedure,
) {
  final headerParameters = _clientHeaderParameters(procedure);
  if (headerParameters.isEmpty) return;
  final typeName = _clientRequestOptionsTypeName(procedure);
  buffer
    ..writeln()
    ..writeln('  /// Typed transport options for `${procedure.rpcMethod}`.')
    ..writeln('  final class $typeName {')
    ..writeln('    const $typeName({');
  for (final parameter in headerParameters) {
    buffer.writeln('      required this.${parameter.parameterName},');
  }
  buffer
    ..writeln('      this.call,')
    ..writeln('    });');
  for (final parameter in headerParameters) {
    buffer.writeln(
      '    final ${parameter.typeCode} ${parameter.parameterName};',
    );
  }
  buffer
    ..writeln('    final RpcCallOptions? call;')
    ..writeln('  }')
    ..writeln();
}

void _writeClientProcedure(StringBuffer buffer, _ResolvedProcedure procedure) {
  final decodeLine = '      decode: ${_clientDecodeExpression(procedure)},';
  final returnType = procedure.isStream ? 'Stream' : 'Future';
  final callerType = procedure.isStream ? 'RpcStreamCaller' : 'RpcCaller';
  final transportExpression = procedure.isStream
      ? "_transports.requireStreaming('${procedure.rpcMethod}')"
      : "_transports.requireUnary('${procedure.rpcMethod}')";
  final callerMethod = procedure.isStream ? 'call' : 'call';
  final headerParameters = _clientHeaderParameters(procedure);
  final hasCallOptions =
      procedure.requiresBearerAuth || headerParameters.isNotEmpty;
  final optionsDeclaration = headerParameters.isNotEmpty
      ? '{required ${_clientRequestOptionsTypeName(procedure)} requestOptions}'
      : hasCallOptions
      ? '{RpcCallOptions? options}'
      : '';
  final optionsExpression = headerParameters.isNotEmpty
      ? _clientCallOptionsExpression('requestOptions', headerParameters)
      : hasCallOptions
      ? 'options'
      : 'null';
  final inputExpression = procedure.hasInput && headerParameters.isNotEmpty
      ? _clientInputExpression(procedure, procedure.inputParameterName!)
      : procedure.hasInput
      ? 'input.toJson()'
      : null;
  if (procedure.isVoid) {
    _writeVoidClientProcedure(
      buffer,
      procedure,
      transportExpression: transportExpression,
    );
    return;
  }
  if (procedure.hasInput) {
    buffer
      ..writeln()
      ..writeln(
        '  $returnType<${procedure.outputTypeCode}> ${procedure.methodName}(${procedure.inputTypeCode!} ${procedure.inputParameterName!}${optionsDeclaration.isEmpty ? '' : ', $optionsDeclaration'}) {',
      )
      ..writeln(
        '    return $callerType($transportExpression).$callerMethod<${procedure.outputTypeCode}>(',
      )
      ..writeln("      method: '${procedure.rpcMethod}',")
      ..writeln('      input: $inputExpression,')
      ..writeln('      options: $optionsExpression,')
      ..writeln(decodeLine)
      ..writeln('    );')
      ..writeln('  }');
    return;
  }
  buffer
    ..writeln()
    ..writeln(
      '  $returnType<${procedure.outputTypeCode}> ${procedure.methodName}(${optionsDeclaration.isEmpty ? '' : optionsDeclaration}) {',
    )
    ..writeln(
      '    return $callerType($transportExpression).$callerMethod<${procedure.outputTypeCode}>(',
    )
    ..writeln("      method: '${procedure.rpcMethod}',")
    ..writeln('      options: $optionsExpression,')
    ..writeln(decodeLine)
    ..writeln('    );')
    ..writeln('  }');
}

String _clientDecodeExpression(_ResolvedProcedure procedure) {
  if (procedure.outputCodecKind == _OutputCodecKind.jsonValue) {
    final typeCode = procedure.outputTypeCode;
    final nullable = typeCode.endsWith('?');
    final nonNullableTypeCode = nullable
        ? typeCode.substring(0, typeCode.length - 1)
        : typeCode;
    final decode = switch (nonNullableTypeCode) {
      'double' => '(json as num).toDouble()',
      'Null' => 'null',
      _ => 'json as $nonNullableTypeCode',
    };
    return nullable
        ? '(json) => json == null ? null : $decode'
        : '(json) => $decode';
  }
  return '(json) => ${procedure.outputTypeCode}.fromJson(Map<String, dynamic>.from(expectJsonObject(json, context: \'RPC response for "${procedure.rpcMethod}"\')))';
}

void _writeVoidClientProcedure(
  StringBuffer buffer,
  _ResolvedProcedure procedure, {
  required String transportExpression,
}) {
  final parameterDeclaration = procedure.hasInput
      ? '${procedure.inputTypeCode!} ${procedure.inputParameterName!}'
      : '';
  final headerParameters = _clientHeaderParameters(procedure);
  final optionsDeclaration = headerParameters.isNotEmpty
      ? '{required ${_clientRequestOptionsTypeName(procedure)} requestOptions}'
      : procedure.requiresBearerAuth
      ? '{RpcCallOptions? options}'
      : '';
  final inputExpression = procedure.hasInput && headerParameters.isNotEmpty
      ? _clientInputExpression(procedure, procedure.inputParameterName!)
      : procedure.hasInput
      ? '${procedure.inputParameterName!}.toJson()'
      : null;
  final optionsExpression = headerParameters.isNotEmpty
      ? _clientCallOptionsExpression('requestOptions', headerParameters)
      : procedure.requiresBearerAuth
      ? 'options'
      : 'null';
  buffer
    ..writeln()
    ..writeln(
      '  Future<void> ${procedure.methodName}($parameterDeclaration${optionsDeclaration.isEmpty ? '' : ', $optionsDeclaration'}) async {',
    )
    ..writeln('    await RpcCaller($transportExpression).call<Null>(')
    ..writeln("      method: '${procedure.rpcMethod}',");
  if (procedure.hasInput) {
    buffer.writeln('      input: $inputExpression,');
  }
  buffer
    ..writeln('      options: $optionsExpression,')
    ..writeln('      decode: (_) => null,')
    ..writeln('    );')
    ..writeln('  }');
}

List<_ResolvedParameter> _clientHeaderParameters(_ResolvedProcedure procedure) {
  return procedure.parameters
      .where(
        (parameter) =>
            parameter.source == ProcedureParameterSourceKind.header &&
            !parameter.typeCode.endsWith('?'),
      )
      .toList(growable: false);
}

String _clientRequestOptionsTypeName(_ResolvedProcedure procedure) {
  return '${_pascalCase(procedure.controllerNamespace)}${_pascalCase(procedure.methodName)}RequestOptions';
}

String _clientInputExpression(_ResolvedProcedure procedure, String inputName) {
  final fields = _clientHeaderParameters(procedure)
      .map((parameter) => "'${_escapeDartString(parameter.parameterName)}'")
      .join(', ');
  return '<String, Object?>{...$inputName.toJson()}..removeWhere((key, _) => [$fields].contains(key))';
}

String _clientCallOptionsExpression(
  String requestOptionsName,
  List<_ResolvedParameter> headerParameters,
) {
  final entries = headerParameters
      .map(
        (parameter) =>
            "'${_escapeDartString(parameter.wireName)}': $requestOptionsName.${parameter.parameterName}",
      )
      .join(', ');
  return 'RpcCallOptions(headers: {...?$requestOptionsName.call?.headers, $entries}, bearerToken: $requestOptionsName.call?.bearerToken)';
}

void _writeGeneratedExtension(
  StringBuffer buffer,
  _ModuleGenerationPlan context,
) {
  final names = context.generatedNames;
  final dependencyFields = _dependencyParameterFields(context);
  final dependencyArguments = _dependencyArgumentList(context);
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
      '  RpcHttpApp buildRpcApp({$dependencyFields${dependencyFields.isEmpty ? '' : ', '}OpenApiDocumentOptions? openApi, RpcHttpDocsOptions? docs, RpcHttpStaticOptions? staticAssets, RpcHttpHealthOptions? health, RpcHttpMetricsOptions? metrics, RpcWebSocketServerOptions? webSocket, RpcContextBindings bindings = const RpcContextBindings.empty(), RpcContextFactory? contextFactory, Duration sseHeartbeatInterval = const Duration(seconds: 15), Iterable<RpcHttpMiddleware> middleware = const []}) => ${names.composeBuildAppName}(${dependencyArguments.isEmpty ? '' : '$dependencyArguments, '}openApi: openApi, docs: docs, staticAssets: staticAssets, health: health, metrics: metrics, webSocket: webSocket, bindings: bindings, contextFactory: contextFactory, sseHeartbeatInterval: sseHeartbeatInterval, middleware: middleware);',
    )
    ..writeln(
      '  ${names.rootClientName} createClient({required RpcClientTransports transports}) => ${names.rootClientName}(transports: transports);',
    )
    ..writeln('}');
}

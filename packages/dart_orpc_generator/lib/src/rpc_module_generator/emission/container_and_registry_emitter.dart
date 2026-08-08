part of '../../rpc_module_generator.dart';

void _writeContainerAndProcedureSections(
  StringBuffer buffer,
  _ModuleGenerationPlan context,
) {
  _writeContainerClass(buffer, context);
  _writeContainerFactory(buffer, context);
  _writeLocalProcedureRegistry(buffer, context);
  _writeProcedureRegistry(buffer, context);
  _writeModuleRuntime(buffer, context);
}

void _writeContainerClass(StringBuffer buffer, _ModuleGenerationPlan context) {
  final names = context.generatedNames;
  buffer.writeln('class ${names.containerClassName} {');
  if (context.containerMembers.isEmpty) {
    buffer.writeln('  ${names.containerClassName}();');
  } else {
    buffer..writeln('  ${names.containerClassName}({');
    for (final member in context.containerMembers) {
      buffer.writeln('    required this.${member.name},');
    }
    buffer
      ..writeln('  });')
      ..writeln();
    for (var index = 0; index < context.containerMembers.length; index++) {
      final member = context.containerMembers[index];
      buffer.writeln('  final ${member.typeName} ${member.name};');
      if (index < context.containerMembers.length - 1) {
        buffer.writeln();
      }
    }
  }
  buffer.writeln('}');
}

void _writeContainerFactory(
  StringBuffer buffer,
  _ModuleGenerationPlan context,
) {
  final names = context.generatedNames;
  final rootModule = context.rootModule;
  buffer
    ..writeln()
    ..writeln(
      '${names.containerClassName} ${names.createContainerName}(${_dependencyParameterDeclaration(context)}) {',
    );
  for (final instantiation in context.importedProviderInstantiations) {
    buffer.writeln('  ${instantiation.code}');
  }
  if (context.importedProviderInstantiations.isNotEmpty &&
      rootModule.providerInstantiations.isNotEmpty) {
    buffer.writeln();
  }
  for (final instantiation in rootModule.providerInstantiations) {
    buffer.writeln('  ${instantiation.code}');
  }
  if ((context.importedProviderInstantiations.isNotEmpty ||
          rootModule.providerInstantiations.isNotEmpty) &&
      rootModule.controllerBindings.isNotEmpty) {
    buffer.writeln();
  }
  for (var index = 0; index < rootModule.allControllers.length; index++) {
    buffer.writeln('  ${rootModule.allControllers[index].instantiationCode}');
    if (index < rootModule.allControllers.length - 1) {
      buffer.writeln();
    }
  }
  buffer..writeln();
  if (context.containerMembers.isEmpty) {
    buffer
      ..writeln('  return ${names.containerClassName}();')
      ..writeln('}');
    return;
  }
  buffer..writeln('  return ${names.containerClassName}(');
  for (final member in context.containerMembers) {
    buffer.writeln('    ${member.name}: ${member.name},');
  }
  buffer
    ..writeln('  );')
    ..writeln('}');
}

void _writeLocalProcedureRegistry(
  StringBuffer buffer,
  _ModuleGenerationPlan context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('// ignore: unused_element')
    ..writeln(
      'RpcProcedureRegistry ${names.createLocalRegistryName}(${_dependencyParameterDeclaration(context)}) {',
    )
    ..writeln(
      '  final container = ${names.createContainerName}(${_dependencyArgumentList(context)});',
    )
    ..writeln('  return ${names.createRegistryFromContainerName}(container);')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'RpcProcedureRegistry ${names.createRegistryFromContainerName}(${names.containerClassName} container) {',
    )
    ..writeln(
      _hasLocalRpcProcedures(context)
          ? '  final metadataRegistry = ${names.createLocalMetadataRegistryName}();'
          : '',
    )
    ..writeln('  return RpcProcedureRegistry([');

  for (final controller in context.rootModule.allControllers) {
    for (final procedure in controller.rpcCompatibleProcedures) {
      final inputTypeCode = procedure.inputTypeCode ?? 'Null';
      final procedureClass = procedure.isStream
          ? 'RpcStreamProcedure'
          : 'RpcUnaryProcedure';
      final invocationExpression =
          'container.${controller.instanceName}.${procedure.methodName}(${procedure.serverInvocationArguments})';
      buffer
        ..writeln(
          '    $procedureClass<$inputTypeCode, ${procedure.outputTypeCode}>(',
        )
        ..writeln("      method: '${procedure.rpcMethod}',")
        ..writeln('      decodeInput: ${_decodeInputExpression(procedure)},')
        ..writeln('      encodeOutput: ${_encodeOutputExpression(procedure)},')
        ..writeln(_rpcGuardInvocationBlock(procedure))
        ..writeln(
          '      handler: ${_serverHandlerExpression(procedure, invocationExpression)},',
        )
        ..writeln('    ),');
    }
  }

  buffer
    ..writeln('  ]);')
    ..writeln('}');
}

void _writeProcedureRegistry(
  StringBuffer buffer,
  _ModuleGenerationPlan context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln(
      'RpcProcedureRegistry ${names.createRegistryName}(${_dependencyParameterDeclaration(context)}) {',
    )
    ..writeln('  return RpcProcedureRegistry([');
  buffer
    ..writeln(
      '    ...${names.createLocalRegistryName}(${_dependencyArgumentList(context)}).procedures,',
    )
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'RpcProcedureRegistry ${names.composeProcedureRegistryName}(${_dependencyParameterDeclaration(context)}) => ${names.createRegistryName}(${_dependencyArgumentList(context)});',
    );
}

void _writeModuleRuntime(StringBuffer buffer, _ModuleGenerationPlan context) {
  final names = context.generatedNames;
  final runtimeType =
      '({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})';

  buffer
    ..writeln()
    ..writeln(
      '$runtimeType ${names.createRuntimeName}(${_dependencyParameterDeclaration(context)}) {',
    );

  buffer
    ..writeln(
      '  final container = ${names.createContainerName}(${_dependencyArgumentList(context)});',
    )
    ..writeln('  final localProcedures =')
    ..writeln('      ${names.createRegistryFromContainerName}(container);')
    ..writeln('  final localRestRoutes =')
    ..writeln(
      '      ${names.createRestRouteRegistryFromContainerName}(container);',
    )
    ..writeln()
    ..writeln('  return (')
    ..writeln('    procedures: RpcProcedureRegistry([');
  buffer
    ..writeln('      ...localProcedures.procedures,')
    ..writeln('    ]),')
    ..writeln('    restRoutes: RestRouteRegistry([');
  buffer
    ..writeln('      ...localRestRoutes.routes,')
    ..writeln('    ]),')
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln(
      '$runtimeType ${names.composeRuntimeName}(${_dependencyParameterDeclaration(context)}) => ${names.createRuntimeName}(${_dependencyArgumentList(context)});',
    );
}

String _dependencyParameterDeclaration(_ModuleGenerationPlan context) {
  if (context.externalProviderRequirements.isEmpty) return '';
  return '{${_dependencyParameterFields(context)}}';
}

String _dependencyParameterFields(_ModuleGenerationPlan context) {
  return context.externalProviderRequirements
      .map(
        (requirement) =>
            'required ${requirement.typeName} ${requirement.variableName}',
      )
      .join(', ');
}

String _dependencyArgumentList(_ModuleGenerationPlan context) {
  if (context.externalProviderRequirements.isEmpty) return '';
  return '${context.externalProviderRequirements.map((requirement) => '${requirement.variableName}: ${requirement.variableName}').join(', ')}';
}

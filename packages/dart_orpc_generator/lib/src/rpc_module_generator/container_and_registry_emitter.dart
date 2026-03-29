part of '../rpc_module_generator.dart';

void _writeContainerAndProcedureSections(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  _writeContainerClass(buffer, context);
  _writeContainerFactory(buffer, context);
  _writeLocalProcedureRegistry(buffer, context);
  _writeProcedureRegistry(buffer, context);
}

void _writeContainerClass(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
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
  _ModuleGenerationContext context,
) {
  final names = context.generatedNames;
  final rootModule = context.rootModule;
  buffer
    ..writeln()
    ..writeln('${names.containerClassName} ${names.createContainerName}() {');
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
  for (var index = 0; index < rootModule.controllerBindings.length; index++) {
    buffer.writeln(
      '  ${rootModule.controllerBindings[index].instantiationCode}',
    );
    if (index < rootModule.controllerBindings.length - 1) {
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
  _ModuleGenerationContext context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('// ignore: unused_element')
    ..writeln('RpcProcedureRegistry ${names.createLocalRegistryName}() {')
    ..writeln('  final container = ${names.createContainerName}();')
    ..writeln('  return ${names.createRegistryFromContainerName}(container);')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'RpcProcedureRegistry ${names.createRegistryFromContainerName}(${names.containerClassName} container) {',
    )
    ..writeln(
      _hasLocalGuardedRpcProcedures(context)
          ? '  final metadataRegistry = ${names.createLocalMetadataRegistryName}();'
          : '',
    )
    ..writeln('  return RpcProcedureRegistry([');

  for (final controller in context.rootModule.controllerBindings) {
    for (final procedure in controller.rpcCompatibleProcedures) {
      final inputTypeCode = procedure.inputTypeCode ?? 'Null';
      buffer
        ..writeln(
          '    RpcProcedure<$inputTypeCode, ${procedure.outputTypeCode}>(',
        )
        ..writeln("      method: '${procedure.rpcMethod}',")
        ..writeln('      decodeInput: ${_decodeInputExpression(procedure)},')
        ..writeln('      encodeOutput: ${_encodeOutputExpression(procedure)},')
        ..writeln(_rpcGuardInvocationBlock(procedure))
        ..writeln(
          '      handler: (context, input) => container.${controller.instanceName}.${procedure.methodName}(${procedure.serverInvocationArguments}),',
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
  _ModuleGenerationContext context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('RpcProcedureRegistry ${names.createRegistryName}() {')
    ..writeln('  return RpcProcedureRegistry([');
  for (final importedModule in context.rootModule.importedModules) {
    buffer.writeln(
      '    ...${_publicProcedureRegistryFactoryNameFor(importedModule.displayName)}().procedures,',
    );
  }
  buffer
    ..writeln('    ...${names.createLocalRegistryName}().procedures,')
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'RpcProcedureRegistry ${names.composeProcedureRegistryName}() => ${names.createRegistryName}();',
    );
}

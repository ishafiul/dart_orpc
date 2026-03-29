part of '../rpc_module_generator.dart';

void _writeRestAndMetadataSections(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  _writeRestRouteRegistries(buffer, context);
  _writeMetadataRegistries(buffer, context);
}

void _writeRestRouteRegistries(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('// ignore: unused_element')
    ..writeln('RestRouteRegistry ${names.createLocalRestRouteRegistryName}() {')
    ..writeln('  final container = ${names.createContainerName}();')
    ..writeln('  return ${names.createRestRouteRegistryFromContainerName}(container);')
    ..writeln('}')
    ..writeln()
    ..writeln('RestRouteRegistry ${names.createRestRouteRegistryFromContainerName}(${names.containerClassName} container) {')
    ..writeln('  return RestRouteRegistry([');

  for (final controller in context.rootModule.controllerBindings) {
    for (final procedure in controller.procedures.where((procedure) => procedure.path != null)) {
      buffer
        ..writeln('    RestRoute(')
        ..writeln("      method: '${procedure.path!.method}',")
        ..writeln("      path: '${procedure.path!.path}',")
        ..writeln('      handler: (context, request, pathParameters) async {');
      if (procedure.restRpcInput != null) {
        for (final declaration in _restRpcInputDeclarations(
          procedure.restRpcInput!,
          procedure,
        )) {
          buffer.writeln('        $declaration');
        }
      }
      for (final parameter in procedure.restInvocationParameters) {
        if (parameter.source != _InvocationParameterSourceKind.rpcInput) {
          final declaration = _restParameterDeclaration(parameter, procedure);
          if (declaration != null) {
            buffer.writeln('        $declaration');
          }
        }
      }
      final invocationArguments = procedure.restInvocationParameters
          .map(_restInvocationArgumentExpression)
          .join(', ');
      buffer
        ..writeln('        final output = await container.${controller.instanceName}.${procedure.methodName}($invocationArguments);')
        ..writeln('        return (${_encodeOutputExpression(procedure)})(output);')
        ..writeln('      },')
        ..writeln('    ),');
    }
  }

  buffer
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln('RestRouteRegistry ${names.createRestRouteRegistryName}() {')
    ..writeln('  return RestRouteRegistry([');
  for (final importedModule in context.rootModule.importedModules) {
    buffer.writeln(
      '    ...${_publicRestRouteRegistryFactoryNameFor(importedModule.displayName)}().routes,',
    );
  }
  buffer
    ..writeln('    ...${names.createLocalRestRouteRegistryName}().routes,')
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln('RestRouteRegistry ${names.composeRestRouteRegistryName}() => ${names.createRestRouteRegistryName}();');
}

void _writeMetadataRegistries(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('// ignore: unused_element')
    ..writeln('ProcedureMetadataRegistry ${names.createLocalMetadataRegistryName}() {')
    ..writeln('  return ProcedureMetadataRegistry([');
  for (final controller in context.rootModule.controllerBindings) {
    for (final procedure in controller.procedures) {
      _writeProcedureMetadata(buffer, procedure);
    }
  }
  buffer
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln('ProcedureMetadataRegistry ${names.createMetadataRegistryName}() {')
    ..writeln('  return ProcedureMetadataRegistry([');
  for (final importedModule in context.rootModule.importedModules) {
    buffer.writeln(
      '    ...${_publicProcedureMetadataRegistryFactoryNameFor(importedModule.displayName)}().procedures,',
    );
  }
  buffer
    ..writeln('    ...${names.createLocalMetadataRegistryName}().procedures,')
    ..writeln('  ]);')
    ..writeln('}')
    ..writeln()
    ..writeln('ProcedureMetadataRegistry ${names.composeMetadataRegistryName}() => ${names.createMetadataRegistryName}();');
}

void _writeProcedureMetadata(StringBuffer buffer, _ResolvedProcedure procedure) {
  buffer
    ..writeln('    const ProcedureMetadata(')
    ..writeln("      rpcMethod: '${procedure.rpcMethod}',")
    ..writeln("      controllerNamespace: '${procedure.controllerNamespace}',")
    ..writeln("      methodName: '${procedure.methodName}',");
  if (procedure.path != null) {
    buffer.writeln("      path: RestProcedureMetadata(method: '${procedure.path!.method}', path: '${procedure.path!.path}'),");
  }
  if (procedure.inputTypeCode != null) {
    buffer.writeln("      inputTypeCode: '${procedure.inputTypeCode}',");
  }
  buffer.writeln("      outputTypeCode: '${procedure.outputTypeCode}',");
  if (procedure.description != null) {
    buffer.writeln("      description: '${_escapeDartString(procedure.description!)}',");
  }
  if (procedure.tags.isNotEmpty) {
    buffer..writeln('      tags: [');
    for (final tag in procedure.tags) {
      buffer.writeln("        '${_escapeDartString(tag)}',");
    }
    buffer.writeln('      ],');
  }
  if (procedure.parameters.isNotEmpty) {
    buffer..writeln('      parameters: [');
    for (final parameter in procedure.parameters) {
      buffer
        ..writeln('        ProcedureParameterMetadata(')
        ..writeln("          parameterName: '${parameter.parameterName}',")
        ..writeln("          wireName: '${parameter.wireName}',")
        ..writeln('          source: ProcedureParameterSourceKind.${parameter.source.name},')
        ..writeln("          typeCode: '${parameter.typeCode}',")
        ..writeln('        ),');
    }
    buffer.writeln('      ],');
  }
  buffer.writeln('    ),');
}

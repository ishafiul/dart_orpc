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
    ..writeln(
      '  return ${names.createRestRouteRegistryFromContainerName}(container);',
    )
    ..writeln('}')
    ..writeln()
    ..writeln(
      'RestRouteRegistry ${names.createRestRouteRegistryFromContainerName}(${names.containerClassName} container) {',
    )
    ..writeln(
      _hasLocalGuardedRestProcedures(context)
          ? '  final metadataRegistry = ${names.createLocalMetadataRegistryName}();'
          : '',
    )
    ..writeln('  return RestRouteRegistry([');

  for (final controller in context.rootModule.controllerBindings) {
    for (final procedure in controller.procedures.where(
      (procedure) => procedure.path != null,
    )) {
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
        ..writeln(_restGuardInvocationBlock(procedure))
        ..writeln(
          '        final output = await container.${controller.instanceName}.${procedure.methodName}($invocationArguments);',
        )
        ..writeln(
          '        return (${_encodeOutputExpression(procedure)})(output);',
        )
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
    ..writeln(
      'RestRouteRegistry ${names.composeRestRouteRegistryName}() => ${names.createRestRouteRegistryName}();',
    );
}

void _writeMetadataRegistries(
  StringBuffer buffer,
  _ModuleGenerationContext context,
) {
  final names = context.generatedNames;
  buffer
    ..writeln()
    ..writeln('// ignore: unused_element')
    ..writeln(
      'ProcedureMetadataRegistry ${names.createLocalMetadataRegistryName}() {',
    )
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
    ..writeln(
      'ProcedureMetadataRegistry ${names.createMetadataRegistryName}() {',
    )
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
    ..writeln(
      'ProcedureMetadataRegistry ${names.composeMetadataRegistryName}() => ${names.createMetadataRegistryName}();',
    );
}

void _writeProcedureMetadata(
  StringBuffer buffer,
  _ResolvedProcedure procedure,
) {
  buffer
    ..writeln('    const ProcedureMetadata(')
    ..writeln("      rpcMethod: '${procedure.rpcMethod}',")
    ..writeln("      controllerNamespace: '${procedure.controllerNamespace}',")
    ..writeln("      methodName: '${procedure.methodName}',");
  if (procedure.path != null) {
    buffer.writeln(
      "      path: RestProcedureMetadata(method: '${procedure.path!.method}', path: '${procedure.path!.path}'),",
    );
  }
  if (procedure.inputTypeCode != null) {
    buffer.writeln("      inputTypeCode: '${procedure.inputTypeCode}',");
  }
  buffer.writeln("      outputTypeCode: '${procedure.outputTypeCode}',");
  if (procedure.description != null) {
    buffer.writeln(
      "      description: '${_escapeDartString(procedure.description!)}',",
    );
  }
  if (procedure.tags.isNotEmpty) {
    buffer..writeln('      tags: [');
    for (final tag in procedure.tags) {
      buffer.writeln("        '${_escapeDartString(tag)}',");
    }
    buffer.writeln('      ],');
  }
  if (procedure.guardTypeNames.isNotEmpty) {
    buffer..writeln('      guardTypes: [');
    for (final guardType in procedure.guardTypeNames) {
      buffer.writeln("        '${_escapeDartString(guardType)}',");
    }
    buffer.writeln('      ],');
  }
  if (procedure.customMetadata.isNotEmpty) {
    buffer..writeln('      customMetadata: [');
    for (final metadata in procedure.customMetadata) {
      buffer.writeln(
        "        ProcedureCustomMetadata(key: '${_escapeDartString(metadata.key)}', value: ${_metadataValueExpression(metadata.value)}),",
      );
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
        ..writeln(
          '          source: ProcedureParameterSourceKind.${parameter.source.name},',
        )
        ..writeln("          typeCode: '${parameter.typeCode}',")
        ..writeln('        ),');
    }
    buffer.writeln('      ],');
  }
  buffer.writeln('    ),');
}

bool _hasLocalGuardedRpcProcedures(_ModuleGenerationContext context) {
  return context.rootModule.controllerBindings.any(
    (controller) => controller.rpcCompatibleProcedures.any(
      (procedure) => procedure.guardBindings.isNotEmpty,
    ),
  );
}

bool _hasLocalGuardedRestProcedures(_ModuleGenerationContext context) {
  return context.rootModule.controllerBindings.any(
    (controller) => controller.procedures.any(
      (procedure) =>
          procedure.path != null && procedure.guardBindings.isNotEmpty,
    ),
  );
}

String _guardInputExpression(_ResolvedProcedure procedure) {
  return procedure.inputParameterName ?? 'null';
}

String _rpcGuardInvocationBlock(_ResolvedProcedure procedure) {
  if (procedure.guardBindings.isEmpty) {
    return '';
  }

  final buffer = StringBuffer()
    ..writeln('      beforeInvoke: (context, input) => runRpcGuards(')
    ..writeln('        [');
  for (final guardBinding in procedure.guardBindings) {
    buffer.writeln('          container.${guardBinding.variableName},');
  }
  buffer
    ..writeln('        ],')
    ..writeln('        rpcContext: context,')
    ..writeln("        procedure: metadataRegistry['${procedure.rpcMethod}']!,")
    ..writeln('        input: input,')
    ..write('      ),');
  return buffer.toString();
}

String _restGuardInvocationBlock(_ResolvedProcedure procedure) {
  if (procedure.guardBindings.isEmpty) {
    return '';
  }

  final buffer = StringBuffer()
    ..writeln('        await runRpcGuards(')
    ..writeln('          [');
  for (final guardBinding in procedure.guardBindings) {
    buffer.writeln('            container.${guardBinding.variableName},');
  }
  buffer
    ..writeln('          ],')
    ..writeln('          rpcContext: context,')
    ..writeln(
      "          procedure: metadataRegistry['${procedure.rpcMethod}']!,",
    )
    ..writeln('          input: ${_guardInputExpression(procedure)},')
    ..write('        );');
  return buffer.toString();
}

String _metadataValueExpression(Object? value) {
  if (value == null) {
    return 'null';
  }
  if (value is String) {
    return "'${_escapeDartString(value)}'";
  }
  if (value is bool || value is num) {
    return '$value';
  }
  if (value is List) {
    return '[${value.map(_metadataValueExpression).join(', ')}]';
  }
  if (value is Map<String, Object?>) {
    final entries = value.entries
        .map(
          (entry) =>
              "'${_escapeDartString(entry.key)}': ${_metadataValueExpression(entry.value)}",
        )
        .join(', ');
    return '{$entries}';
  }

  throw StateError('Unsupported procedure custom metadata value: $value');
}

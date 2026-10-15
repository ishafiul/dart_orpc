part of '../../rpc_module_generator.dart';

Map<String, _ResolvedProviderBinding> _resolveExportedProviders(
  List<InterfaceElement> exportElements, {
  required InterfaceElement moduleElement,
  required List<_ResolvedModule> importedModules,
  required Map<String, _ResolvedProviderBinding> importedProviders,
  required Map<String, _ResolvedProviderBinding> localProviders,
}) {
  final importedModuleByTypeKey = {
    for (final importedModule in importedModules)
      importedModule.typeKey: importedModule,
  };
  final exportedProviders = <String, _ResolvedProviderBinding>{};

  for (final exportElement in exportElements) {
    final exportTypeKey = _typeKeyFor(exportElement.thisType);
    final importedModule = importedModuleByTypeKey[exportTypeKey];
    if (importedModule != null) {
      for (final provider in importedModule.exportedProviders.values) {
        _recordProviderBinding(
          exportedProviders,
          provider,
          moduleElement: moduleElement,
        );
      }
      continue;
    }

    final provider =
        localProviders[exportTypeKey] ?? importedProviders[exportTypeKey];
    if (provider != null) {
      _recordProviderBinding(
        exportedProviders,
        provider,
        moduleElement: moduleElement,
      );
      continue;
    }

    final message = _moduleChecker.hasAnnotationOfExact(exportElement)
        ? 'Module "${moduleElement.displayName}" may only export modules listed in @Module.imports. Unknown module export "${exportElement.displayName}".'
        : 'Module "${moduleElement.displayName}" may only export its own providers or providers/modules from @Module.imports. Unknown export "${exportElement.displayName}".';
    throw InvalidGenerationSourceError(message, element: moduleElement);
  }

  return exportedProviders;
}

void _recordProviderBinding(
  Map<String, _ResolvedProviderBinding> target,
  _ResolvedProviderBinding provider, {
  required InterfaceElement moduleElement,
}) {
  final existingProvider = target[provider.typeKey];
  if (existingProvider == null) {
    target[provider.typeKey] = provider;
    return;
  }
  if (existingProvider.variableName == provider.variableName) {
    return;
  }
  throw InvalidGenerationSourceError(
    'Module "${moduleElement.displayName}" resolves provider type "${provider.typeName}" from more than one source (${existingProvider.sourceLabel}, ${provider.sourceLabel}).',
    element: moduleElement,
  );
}

List<_ResolvedInstantiation> _resolveProviderInstantiations(
  List<_ProviderDefinition> providers, {
  required Map<String, _ResolvedProviderBinding> importedProviders,
  Map<String, String> externalProviders = const {},
  Map<String, String> forcedVariableNames = const {},
  required Set<String> usedNames,
  required Element moduleElement,
}) {
  final resolved = <_ResolvedInstantiation>[];
  final availableProviders = {
    for (final provider in importedProviders.values)
      provider.typeKey: provider.variableName,
    ...externalProviders,
  };
  final declaredProviderNames = <String>{};
  final remainingProviders = [...providers];

  for (final provider in providers) {
    if (!declaredProviderNames.add(provider.typeKey)) {
      throw InvalidGenerationSourceError(
        'Module "${moduleElement.displayName}" declares provider "${provider.typeName}" more than once.',
        element: provider.providerElement,
      );
    }
    final conflictingImportedProvider = importedProviders[provider.typeKey];
    if (conflictingImportedProvider != null) {
      throw InvalidGenerationSourceError(
        'Module "${moduleElement.displayName}" declares provider "${provider.typeName}" that conflicts with ${conflictingImportedProvider.sourceLabel}.',
        element: provider.providerElement,
      );
    }
  }

  while (remainingProviders.isNotEmpty) {
    var progressed = false;
    for (final provider in List<_ProviderDefinition>.from(remainingProviders)) {
      final instantiation = _tryBuildInstantiation(
        provider,
        availableProviders: availableProviders,
        usedNames: usedNames,
        forcedVariableName: forcedVariableNames[provider.typeKey],
      );
      if (instantiation == null) {
        continue;
      }
      resolved.add(instantiation);
      availableProviders[instantiation.typeKey] = instantiation.variableName;
      remainingProviders.remove(provider);
      progressed = true;
    }
    if (progressed) {
      continue;
    }
    final cycle = _findProviderDependencyCycle(remainingProviders);
    if (cycle != null) {
      throw InvalidGenerationSourceError(
        'Provider dependency cycle: ${cycle.join(' -> ')}.',
        element: moduleElement,
      );
    }
    throw InvalidGenerationSourceError(
      'Unable to resolve provider dependencies for: ${remainingProviders.map((provider) => provider.typeName).join(', ')}.',
      element: moduleElement,
    );
  }

  return resolved;
}

List<String>? _findProviderDependencyCycle(
  List<_ProviderDefinition> providers,
) {
  final providersByType = {
    for (final provider in providers) provider.typeKey: provider,
  };

  List<String>? walk(_ProviderDefinition provider, List<String> path) {
    final typeKey = provider.typeKey;
    final cycleStart = path.indexOf(typeKey);
    if (cycleStart != -1) {
      return [
        ...path.skip(cycleStart).map(_providerNameForTypeKey),
        provider.typeName,
      ];
    }
    final nextPath = [...path, typeKey];
    for (final parameter in provider.parameters) {
      if (parameter.isOptional) continue;
      final next = providersByType[_dependencyTypeKeyFor(parameter.type)];
      if (next == null) continue;
      final cycle = walk(next, nextPath);
      if (cycle != null) return cycle;
    }
    return null;
  }

  for (final provider in providers) {
    final cycle = walk(provider, const []);
    if (cycle != null) return cycle;
  }
  return null;
}

String _providerNameForTypeKey(String typeKey) {
  final separator = typeKey.lastIndexOf(':');
  return separator == -1 ? typeKey : typeKey.substring(separator + 1);
}

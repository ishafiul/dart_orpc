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

  final dependencies = {
    for (final provider in providers)
      provider.typeKey: [
        for (final parameter in provider.parameters)
          if (!parameter.isOptional) _dependencyTypeKeyFor(parameter.type),
      ],
  };
  final sorted = topologicalSort<_ProviderDefinition, String>(
    providers,
    keyOf: (provider) => provider.typeKey,
    dependenciesOf: (provider) => dependencies[provider.typeKey]!,
    available: availableProviders.keys,
  );
  if (sorted.unresolved.isNotEmpty) {
    final unresolvedByKey = {
      for (final provider in sorted.unresolved) provider.typeKey: provider,
    };
    final cycle = findDependencyCycle<_ProviderDefinition, String>(
      sorted.unresolved,
      keyOf: (provider) => provider.typeKey,
      dependenciesOf: (provider) => [
        for (final key in dependencies[provider.typeKey]!)
          if (unresolvedByKey[key] case final dependency?) dependency,
      ],
    );
    if (cycle != null) {
      throw InvalidGenerationSourceError(
        'Provider dependency cycle: ${cycle.map((provider) => provider.typeName).join(' -> ')}.',
        element: moduleElement,
      );
    }
    throw InvalidGenerationSourceError(
      'Unable to resolve provider dependencies for: ${sorted.unresolved.map((provider) => provider.typeName).join(', ')}.',
      element: moduleElement,
    );
  }

  for (final provider in sorted.ordered) {
    final instantiation = _tryBuildInstantiation(
      provider,
      availableProviders: availableProviders,
      usedNames: usedNames,
      forcedVariableName: forcedVariableNames[provider.typeKey],
    );
    if (instantiation == null) {
      throw StateError('Invalid dependency order for "${provider.typeName}".');
    }
    resolved.add(instantiation);
    availableProviders[instantiation.typeKey] = instantiation.variableName;
  }
  return resolved;
}

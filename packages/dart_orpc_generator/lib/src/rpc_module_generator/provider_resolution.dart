part of '../rpc_module_generator.dart';

Map<String, _ResolvedProviderBinding> _mergeImportedProviders(
  List<_ResolvedModule> importedModules, {
  required InterfaceElement moduleElement,
}) {
  final importedProviders = <String, _ResolvedProviderBinding>{};
  for (final importedModule in importedModules) {
    for (final provider in importedModule.exportedProviders.values) {
      _recordProviderBinding(
        importedProviders,
        provider,
        moduleElement: moduleElement,
      );
    }
  }
  return importedProviders;
}

Map<String, _ResolvedProviderBinding> _resolveExportedProviders(
  ConstantReader reader, {
  required InterfaceElement moduleElement,
  required List<_ResolvedModule> importedModules,
  required Map<String, _ResolvedProviderBinding> importedProviders,
  required Map<String, _ResolvedProviderBinding> localProviders,
}) {
  final exportElements = _readInterfaceElements(
    reader,
    element: moduleElement,
    fieldName: 'exports',
  );
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
  List<InterfaceElement> providers, {
  required Map<String, _ResolvedProviderBinding> importedProviders,
  required Set<String> usedNames,
  required Element moduleElement,
}) {
  final resolved = <_ResolvedInstantiation>[];
  final availableProviders = {
    for (final provider in importedProviders.values)
      provider.typeKey: provider.variableName,
  };
  final declaredProviderNames = <String>{};
  final remainingProviders = [...providers];

  for (final provider in providers) {
    final typeKey = _typeKeyFor(provider.thisType);
    if (!declaredProviderNames.add(typeKey)) {
      throw InvalidGenerationSourceError(
        'Module "${moduleElement.displayName}" declares provider "${provider.displayName}" more than once.',
        element: moduleElement,
      );
    }
    final conflictingImportedProvider = importedProviders[typeKey];
    if (conflictingImportedProvider != null) {
      throw InvalidGenerationSourceError(
        'Module "${moduleElement.displayName}" declares provider "${provider.displayName}" that conflicts with ${conflictingImportedProvider.sourceLabel}.',
        element: moduleElement,
      );
    }
  }

  while (remainingProviders.isNotEmpty) {
    var progressed = false;
    for (final provider in List<InterfaceElement>.from(remainingProviders)) {
      final instantiation = _tryBuildInstantiation(
        provider,
        availableProviders: availableProviders,
        usedNames: usedNames,
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
    throw InvalidGenerationSourceError(
      'Unable to resolve provider constructor dependencies for: ${remainingProviders.map((provider) => provider.displayName).join(', ')}.',
      element: moduleElement,
    );
  }

  return resolved;
}

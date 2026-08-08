part of '../../rpc_module_generator.dart';

_ResolvedModuleGraph _resolveModuleGraph(
  InterfaceElement rootModule, {
  required ConstantReader annotation,
  required Set<String> usedNames,
}) {
  final declarations = <String, _ModuleDeclaration>{};
  final orderedDeclarations = <_ModuleDeclaration>[];

  _discoverModule(
    rootModule,
    annotation: annotation,
    declarations: declarations,
    orderedDeclarations: orderedDeclarations,
    stack: const [],
  );

  final exportedProviderDeclarations = <String, _DeclaredProvider>{};
  final exportCache = <String, Map<String, _DeclaredProvider>>{};
  for (final declaration in orderedDeclarations.where(
    (module) => module.isGlobal,
  )) {
    for (final provider in _declaredExportsFor(
      declaration,
      exportCache,
    ).values) {
      final existing = exportedProviderDeclarations[provider.typeKey];
      if (existing != null && existing.ownerTypeKey != provider.ownerTypeKey) {
        throw InvalidGenerationSourceError(
          'Global provider "${provider.typeName}" is exported by both "${existing.ownerName}" and "${provider.ownerName}".',
          element: declaration.moduleElement,
        );
      }
      exportedProviderDeclarations[provider.typeKey] = provider;
    }
  }

  final forcedGlobalNames = <String, String>{};
  final globalBindings = <String, _ResolvedProviderBinding>{};
  final privateGlobalProviderKeys = <String>{};
  for (final declaration in orderedDeclarations.where(
    (module) => module.isGlobal,
  )) {
    final exportedKeys = _declaredExportsFor(declaration, exportCache).keys;
    for (final provider in declaration.providers) {
      final typeKey = _typeKeyFor(provider.thisType);
      if (!exportedKeys.contains(typeKey)) {
        privateGlobalProviderKeys.add(typeKey);
      }
    }
  }
  for (final provider in exportedProviderDeclarations.values) {
    final variableName = _uniqueName(_lowerCamel(provider.typeName), usedNames);
    forcedGlobalNames[provider.typeKey] = variableName;
    globalBindings[provider.typeKey] = _ResolvedProviderBinding(
      typeKey: provider.typeKey,
      typeName: provider.typeName,
      variableName: variableName,
      sourceLabel:
          'global provider "${provider.typeName}" from "${provider.ownerName}"',
    );
  }

  final resolvedModules = <String, _ResolvedModule>{};
  final orderedModules = <_ResolvedModule>[];
  for (final declaration in orderedDeclarations) {
    final importedProviders = <String, _ResolvedProviderBinding>{
      ...globalBindings,
    };
    for (final importedModule in declaration.importedModules) {
      final resolvedImported = resolvedModules[importedModule.typeKey];
      if (resolvedImported == null) {
        throw InvalidGenerationSourceError(
          'Module "${declaration.displayName}" imports "${importedModule.displayName}" before it can be resolved.',
          element: declaration.moduleElement,
        );
      }
      for (final provider in resolvedImported.exportedProviders.values) {
        _recordProviderBinding(
          importedProviders,
          provider,
          moduleElement: declaration.moduleElement,
        );
      }
    }

    final localProviderKeys = {
      for (final provider in declaration.providers)
        _typeKeyFor(provider.thisType),
    };
    final visibleImportedProviders =
        Map<String, _ResolvedProviderBinding>.from(importedProviders)
          ..removeWhere(
            (typeKey, _) =>
                declaration.isGlobal && localProviderKeys.contains(typeKey),
          );
    if (!declaration.isGlobal) {
      for (final provider in declaration.providers) {
        if (globalBindings.containsKey(_typeKeyFor(provider.thisType))) {
          throw InvalidGenerationSourceError(
            'Module "${declaration.displayName}" declares provider "${provider.displayName}" that shadows a global provider.',
            element: provider,
          );
        }
      }
    }

    final externalRequirements = _resolveExternalProviderRequirements(
      declaration,
      visibleProviders: visibleImportedProviders,
      localProviderKeys: localProviderKeys,
      privateGlobalProviderKeys: privateGlobalProviderKeys,
      usedNames: usedNames,
    );
    final externalProviders = {
      for (final requirement in externalRequirements)
        requirement.typeKey: requirement.variableName,
    };
    final providerInstantiations = _resolveProviderInstantiations(
      declaration.providers,
      importedProviders: visibleImportedProviders,
      externalProviders: externalProviders,
      forcedVariableNames: forcedGlobalNames,
      usedNames: usedNames,
      moduleElement: declaration.moduleElement,
    );
    final localProviders = {
      for (final instantiation in providerInstantiations)
        instantiation.typeKey: _ResolvedProviderBinding(
          typeKey: instantiation.typeKey,
          typeName: instantiation.typeName,
          variableName: instantiation.variableName,
          sourceLabel:
              'provider "${instantiation.typeName}" from module "${declaration.displayName}"',
        ),
    };
    final availableProviders = <String, String>{
      for (final provider in visibleImportedProviders.values)
        provider.typeKey: provider.variableName,
      ...externalProviders,
      for (final provider in localProviders.values)
        provider.typeKey: provider.variableName,
    };
    final controllerBindings = declaration.controllers
        .map(
          (controller) => _buildControllerBinding(
            controller,
            availableProviders: availableProviders,
            usedNames: usedNames,
          ),
        )
        .toList(growable: false);
    final resolvedModule = _ResolvedModule(
      typeKey: declaration.typeKey,
      displayName: declaration.displayName,
      moduleElement: declaration.moduleElement,
      importedModules: declaration.importedModules
          .map((module) => resolvedModules[module.typeKey]!)
          .toList(growable: false),
      importedProviders: visibleImportedProviders,
      providerInstantiations: providerInstantiations,
      controllerBindings: controllerBindings,
      exportedProviders: _resolveExportedProviders(
        declaration.exports,
        moduleElement: declaration.moduleElement,
        importedModules: declaration.importedModules
            .map((module) => resolvedModules[module.typeKey]!)
            .toList(growable: false),
        importedProviders: visibleImportedProviders,
        localProviders: localProviders,
      ),
      isGlobal: declaration.isGlobal,
      externalProviderRequirements: externalRequirements,
    );
    resolvedModules[declaration.typeKey] = resolvedModule;
    orderedModules.add(resolvedModule);
  }

  final resolvedGlobalProviders = <String, _ResolvedProviderBinding>{};
  for (final module in orderedModules.where((module) => module.isGlobal)) {
    for (final provider in module.exportedProviders.values) {
      _recordProviderBinding(
        resolvedGlobalProviders,
        provider,
        moduleElement: module.moduleElement,
      );
    }
  }
  return _ResolvedModuleGraph(
    orderedModules: orderedModules,
    globalProviders: resolvedGlobalProviders,
  );
}

_ModuleDeclaration _discoverModule(
  InterfaceElement moduleElement, {
  required ConstantReader? annotation,
  required Map<String, _ModuleDeclaration> declarations,
  required List<_ModuleDeclaration> orderedDeclarations,
  required List<_VisitedModule> stack,
}) {
  final typeKey = _typeKeyFor(moduleElement.thisType);
  final cached = declarations[typeKey];
  if (cached != null) return cached;

  final cycleStartIndex = stack.indexWhere(
    (visitedModule) => visitedModule.typeKey == typeKey,
  );
  if (cycleStartIndex != -1) {
    final cycle = [
      for (final visitedModule in stack.skip(cycleStartIndex))
        visitedModule.displayName,
      moduleElement.displayName,
    ].join(' -> ');
    throw InvalidGenerationSourceError(
      'Detected circular @Module.imports chain: $cycle.',
      element: moduleElement,
    );
  }

  final resolvedAnnotation = annotation ?? _readModuleAnnotation(moduleElement);
  final importedElements = _readModuleElements(
    resolvedAnnotation.read('imports'),
    element: moduleElement,
    fieldName: 'imports',
  );
  final importedModules = importedElements
      .map(
        (importedModule) => _discoverModule(
          importedModule,
          annotation: null,
          declarations: declarations,
          orderedDeclarations: orderedDeclarations,
          stack: [
            ...stack,
            _VisitedModule(
              typeKey: typeKey,
              displayName: moduleElement.displayName,
            ),
          ],
        ),
      )
      .toList(growable: false);
  final declaration = _ModuleDeclaration(
    typeKey: typeKey,
    displayName: moduleElement.displayName,
    moduleElement: moduleElement,
    importedModules: importedModules,
    controllers: _readInterfaceElements(
      resolvedAnnotation.read('controllers'),
      element: moduleElement,
      fieldName: 'controllers',
    ),
    providers: _readInterfaceElements(
      resolvedAnnotation.read('providers'),
      element: moduleElement,
      fieldName: 'providers',
    ),
    exports: _readInterfaceElements(
      resolvedAnnotation.read('exports'),
      element: moduleElement,
      fieldName: 'exports',
    ),
    isGlobal: resolvedAnnotation.read('global').boolValue,
  );
  declarations[typeKey] = declaration;
  orderedDeclarations.add(declaration);
  return declaration;
}

Map<String, _DeclaredProvider> _declaredExportsFor(
  _ModuleDeclaration declaration,
  Map<String, Map<String, _DeclaredProvider>> cache,
) {
  final cached = cache[declaration.typeKey];
  if (cached != null) return cached;
  final importedByType = <String, _DeclaredProvider>{};
  for (final importedModule in declaration.importedModules) {
    for (final provider in _declaredExportsFor(importedModule, cache).values) {
      _recordDeclaredProvider(importedByType, provider, declaration);
    }
  }
  final localByType = {
    for (final provider in declaration.providers)
      _typeKeyFor(provider.thisType): _DeclaredProvider(
        typeKey: _typeKeyFor(provider.thisType),
        typeName: provider.displayName,
        ownerTypeKey: declaration.typeKey,
        ownerName: declaration.displayName,
      ),
  };
  final exported = <String, _DeclaredProvider>{};
  for (final exportElement in declaration.exports) {
    final importedModule = declaration.importedModules.where(
      (module) => module.typeKey == _typeKeyFor(exportElement.thisType),
    );
    if (importedModule.isNotEmpty) {
      for (final provider in _declaredExportsFor(
        importedModule.single,
        cache,
      ).values) {
        _recordDeclaredProvider(exported, provider, declaration);
      }
      continue;
    }
    final provider =
        localByType[_typeKeyFor(exportElement.thisType)] ??
        importedByType[_typeKeyFor(exportElement.thisType)];
    if (provider == null) {
      continue;
    }
    _recordDeclaredProvider(exported, provider, declaration);
  }
  cache[declaration.typeKey] = exported;
  return exported;
}

void _recordDeclaredProvider(
  Map<String, _DeclaredProvider> target,
  _DeclaredProvider provider,
  _ModuleDeclaration declaration,
) {
  final existing = target[provider.typeKey];
  if (existing != null && existing.ownerTypeKey != provider.ownerTypeKey) {
    throw InvalidGenerationSourceError(
      'Module "${declaration.displayName}" exports provider "${provider.typeName}" from more than one source.',
      element: declaration.moduleElement,
    );
  }
  target[provider.typeKey] = provider;
}

final class _DeclaredProvider {
  const _DeclaredProvider({
    required this.typeKey,
    required this.typeName,
    required this.ownerTypeKey,
    required this.ownerName,
  });

  final String typeKey;
  final String typeName;
  final String ownerTypeKey;
  final String ownerName;
}

List<_ExternalProviderRequirement> _resolveExternalProviderRequirements(
  _ModuleDeclaration declaration, {
  required Map<String, _ResolvedProviderBinding> visibleProviders,
  required Set<String> localProviderKeys,
  required Set<String> privateGlobalProviderKeys,
  required Set<String> usedNames,
}) {
  final requirements = <String, _ExternalProviderRequirement>{};

  void addType(DartType type) {
    final interfaceType = type is InterfaceType ? type : null;
    final element = interfaceType?.element;
    if (element == null || element.displayName == 'Object') return;
    final typeKey = _typeKeyFor(type);
    if (visibleProviders.containsKey(typeKey) ||
        localProviderKeys.contains(typeKey)) {
      return;
    }
    if (privateGlobalProviderKeys.contains(typeKey)) {
      throw InvalidGenerationSourceError(
        'Module "${declaration.displayName}" requires a private provider that is declared by a global module. Export the provider from that module.',
        element: declaration.moduleElement,
      );
    }
    requirements.putIfAbsent(
      typeKey,
      () => _ExternalProviderRequirement(
        typeKey: typeKey,
        typeName: element.displayName,
        typeElement: element,
        variableName: _uniqueName(_lowerCamel(element.displayName), usedNames),
      ),
    );
  }

  for (final provider in declaration.providers) {
    for (final parameter in _selectUnnamedConstructor(
      provider,
    ).formalParameters) {
      addType(parameter.type);
    }
  }
  for (final controller in declaration.controllers) {
    for (final parameter in _selectUnnamedConstructor(
      controller,
    ).formalParameters) {
      addType(parameter.type);
    }
  }
  return requirements.values.toList(growable: false);
}

ConstantReader _readModuleAnnotation(InterfaceElement moduleElement) {
  final annotation = _moduleChecker.firstAnnotationOfExact(moduleElement);
  if (annotation == null) {
    throw InvalidGenerationSourceError(
      'Module "${moduleElement.displayName}" must be annotated with @Module.',
      element: moduleElement,
    );
  }
  return ConstantReader(annotation);
}

List<InterfaceElement> _readModuleElements(
  ConstantReader reader, {
  required Element element,
  required String fieldName,
}) {
  final moduleElements = _readInterfaceElements(
    reader,
    element: element,
    fieldName: fieldName,
  );
  for (final moduleElement in moduleElements) {
    if (!_moduleChecker.hasAnnotationOfExact(moduleElement)) {
      throw InvalidGenerationSourceError(
        '@Module.$fieldName entries must be classes annotated with @Module.',
        element: moduleElement,
      );
    }
  }
  return moduleElements;
}

List<InterfaceElement> _readInterfaceElements(
  ConstantReader reader, {
  required Element element,
  required String fieldName,
}) {
  return reader.listValue
      .map((object) {
        final type = object.toTypeValue();
        if (type is! InterfaceType) {
          throw InvalidGenerationSourceError(
            '@Module.$fieldName entries must be class types.',
            element: element,
          );
        }
        return type.element;
      })
      .toList(growable: false);
}

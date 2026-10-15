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
      if (!exportedKeys.contains(provider.typeKey)) {
        privateGlobalProviderKeys.add(provider.typeKey);
      }
    }
  }
  for (final provider in exportedProviderDeclarations.values) {
    final variableName = _uniqueName(
      _lowerCamel(provider.tokenElement.displayName),
      usedNames,
    );
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
      for (final provider in declaration.providers) provider.typeKey,
    };
    final visibleImportedProviders =
        Map<String, _ResolvedProviderBinding>.from(importedProviders)
          ..removeWhere(
            (typeKey, _) =>
                declaration.isGlobal && localProviderKeys.contains(typeKey),
          );
    for (final provider in declaration.providers) {
      final typeKey = provider.typeKey;
      final globalProvider = exportedProviderDeclarations[typeKey];
      if (globalProvider != null &&
          globalProvider.ownerTypeKey != declaration.typeKey) {
        throw InvalidGenerationSourceError(
          'Module "${declaration.displayName}" declares provider "${provider.typeName}" that shadows a global provider.',
          element: provider.providerElement,
        );
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
    providers: _readProviderDefinitions(
      resolvedAnnotation,
      element: moduleElement,
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

List<_ProviderDefinition> _readProviderDefinitions(
  ConstantReader moduleAnnotation, {
  required Element element,
}) {
  final providers = <_ProviderDefinition>[];
  for (final providerObject in moduleAnnotation.read('providers').listValue) {
    final providerType = providerObject.toTypeValue();
    if (providerType is! InterfaceType) {
      throw InvalidGenerationSourceError(
        '@Module.providers entries must be class types.',
        element: element,
      );
    }
    providers.add(
      _classProviderDefinition(providerType, providerType, element: element),
    );
  }

  for (final bindingObject in moduleAnnotation.read('bindings').listValue) {
    final binding = ConstantReader(bindingObject);
    final providedType = binding.read('provide').typeValue;
    if (providedType is! InterfaceType) {
      throw InvalidGenerationSourceError(
        '@Module.bindings provide entries must be interface types.',
        element: element,
      );
    }
    final useClass = binding.read('useClass');
    if (!useClass.isNull) {
      providers.add(
        _classProviderDefinition(
          providedType,
          useClass.typeValue,
          element: element,
        ),
      );
      continue;
    }

    final factory = binding.read('factory').objectValue.toFunctionValue();
    if (factory == null) {
      throw InvalidGenerationSourceError(
        '@Module.bindings must declare either useClass or a top-level/static factory.',
        element: element,
      );
    }
    providers.add(_factoryProviderDefinition(providedType, factory));
  }

  return providers;
}

_ProviderDefinition _classProviderDefinition(
  InterfaceType providedType,
  DartType? implementationType, {
  required Element element,
}) {
  if (implementationType is! InterfaceType) {
    throw InvalidGenerationSourceError(
      '@Module.bindings useClass entries must be class types.',
      element: element,
    );
  }
  if (providedType.element.displayName.startsWith('_')) {
    throw InvalidGenerationSourceError(
      'Provider token "${providedType.element.displayName}" must be public because generated code references it from another library.',
      element: providedType.element,
    );
  }
  final implementation = implementationType.element;
  if (implementation is! ClassElement) {
    throw InvalidGenerationSourceError(
      'Provider implementation "${implementation.displayName}" must be a class.',
      element: implementation,
    );
  }
  if (implementation.displayName.startsWith('_')) {
    throw InvalidGenerationSourceError(
      'Provider implementation "${implementation.displayName}" must be public because generated code references it from another library.',
      element: implementation,
    );
  }
  if (implementation.isAbstract) {
    throw InvalidGenerationSourceError(
      'Provider implementation "${implementation.displayName}" must be concrete.',
      element: implementation,
    );
  }
  if (!providedType.element.library.typeSystem.isSubtypeOf(
    implementationType,
    providedType,
  )) {
    throw InvalidGenerationSourceError(
      'Provider implementation "${implementation.displayName}" is not assignable to "${providedType.getDisplayString()}".',
      element: implementation,
    );
  }
  final constructor = _selectUnnamedConstructor(implementation);
  return _ProviderDefinition(
    typeKey: _typeKeyFor(providedType),
    typeName: providedType.getDisplayString(),
    tokenElement: providedType.element,
    providerElement: implementation,
    creationTarget: implementationType.getDisplayString(),
    parameters: constructor.formalParameters,
  );
}

_ProviderDefinition _factoryProviderDefinition(
  InterfaceType providedType,
  ExecutableElement factory,
) {
  if (providedType.element.displayName.startsWith('_')) {
    throw InvalidGenerationSourceError(
      'Provider token "${providedType.element.displayName}" must be public because generated code references it from another library.',
      element: providedType.element,
    );
  }
  final enclosingElement = factory.enclosingElement;
  if (factory.displayName.startsWith('_') ||
      (enclosingElement is InterfaceElement &&
          enclosingElement.displayName.startsWith('_'))) {
    throw InvalidGenerationSourceError(
      'Provider factory "${factory.displayName}" must be public because generated code references it from another library.',
      element: factory,
    );
  }
  if (enclosingElement is InterfaceElement && !factory.isStatic) {
    throw InvalidGenerationSourceError(
      'Provider factory "${factory.displayName}" must be top-level or static.',
      element: factory,
    );
  }
  if (_isFutureType(factory.returnType)) {
    throw InvalidGenerationSourceError(
      'Provider factory "${factory.displayName}" must be synchronous.',
      element: factory,
    );
  }
  if (!providedType.element.library.typeSystem.isSubtypeOf(
    factory.returnType,
    providedType,
  )) {
    throw InvalidGenerationSourceError(
      'Provider factory "${factory.displayName}" must return an instance assignable to "${providedType.getDisplayString()}".',
      element: factory,
    );
  }

  final invocationTarget = enclosingElement is InterfaceElement
      ? '${enclosingElement.displayName}.${factory.displayName}'
      : factory.displayName;
  return _ProviderDefinition(
    typeKey: _typeKeyFor(providedType),
    typeName: providedType.getDisplayString(),
    tokenElement: providedType.element,
    providerElement: factory,
    creationTarget: invocationTarget,
    parameters: factory.formalParameters,
  );
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
      provider.typeKey: _DeclaredProvider(
        typeKey: provider.typeKey,
        typeName: provider.typeName,
        tokenElement: provider.tokenElement,
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
    required this.tokenElement,
    required this.ownerTypeKey,
    required this.ownerName,
  });

  final String typeKey;
  final String typeName;
  final InterfaceElement tokenElement;
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
    final typeKey = _dependencyTypeKeyFor(type);
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
    if (element.displayName.startsWith('_')) {
      throw InvalidGenerationSourceError(
        'Module "${declaration.displayName}" requires private dependency "${element.displayName}", which generated code cannot reference from another library.',
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
    for (final parameter in provider.parameters) {
      if (parameter.isOptional) continue;
      addType(parameter.type);
    }
  }
  for (final controller in declaration.controllers) {
    for (final parameter in _selectUnnamedConstructor(
      controller,
    ).formalParameters) {
      if (parameter.isOptional) continue;
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

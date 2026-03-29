part of '../rpc_module_generator.dart';

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

_ResolvedModuleGraph _resolveModuleGraph(
  InterfaceElement rootModule, {
  required ConstantReader annotation,
  required Set<String> usedNames,
}) {
  final resolvedModules = <String, _ResolvedModule>{};
  final orderedModules = <_ResolvedModule>[];

  _resolveModule(
    rootModule,
    annotation: annotation,
    usedNames: usedNames,
    resolvedModules: resolvedModules,
    orderedModules: orderedModules,
    stack: const [],
  );

  return _ResolvedModuleGraph(orderedModules: orderedModules);
}

_ResolvedModule _resolveModule(
  InterfaceElement moduleElement, {
  ConstantReader? annotation,
  required Set<String> usedNames,
  required Map<String, _ResolvedModule> resolvedModules,
  required List<_ResolvedModule> orderedModules,
  required List<_VisitedModule> stack,
}) {
  final moduleTypeKey = _typeKeyFor(moduleElement.thisType);
  final cachedModule = resolvedModules[moduleTypeKey];
  if (cachedModule != null) {
    return cachedModule;
  }

  final cycleStartIndex = stack.indexWhere(
    (visitedModule) => visitedModule.typeKey == moduleTypeKey,
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

  final annotationReader = annotation ?? _readModuleAnnotation(moduleElement);
  final importedModuleElements = _readModuleElements(
    annotationReader.read('imports'),
    element: moduleElement,
    fieldName: 'imports',
  );
  final importedModules = importedModuleElements
      .map(
        (importedModule) => _resolveModule(
          importedModule,
          usedNames: usedNames,
          resolvedModules: resolvedModules,
          orderedModules: orderedModules,
          stack: [
            ...stack,
            _VisitedModule(
              typeKey: moduleTypeKey,
              displayName: moduleElement.displayName,
            ),
          ],
        ),
      )
      .toList(growable: false);

  final importedProviders = _mergeImportedProviders(
    importedModules,
    moduleElement: moduleElement,
  );
  final providerInstantiations = _resolveProviderInstantiations(
    _readInterfaceElements(
      annotationReader.read('providers'),
      element: moduleElement,
      fieldName: 'providers',
    ),
    importedProviders: importedProviders,
    usedNames: usedNames,
    moduleElement: moduleElement,
  );
  final localProviders = {
    for (final instantiation in providerInstantiations)
      instantiation.typeKey: _ResolvedProviderBinding(
        typeKey: instantiation.typeKey,
        typeName: instantiation.typeName,
        variableName: instantiation.variableName,
        sourceLabel:
            'provider "${instantiation.typeName}" from module "${moduleElement.displayName}"',
      ),
  };

  final controllerBindings = _readInterfaceElements(
    annotationReader.read('controllers'),
    element: moduleElement,
    fieldName: 'controllers',
  )
      .map(
        (controllerElement) => _buildControllerBinding(
          controllerElement,
          availableProviders: {
            for (final provider in importedProviders.values)
              provider.typeKey: provider.variableName,
            for (final provider in localProviders.values)
              provider.typeKey: provider.variableName,
          },
          usedNames: usedNames,
        ),
      )
      .toList(growable: false);

  final resolvedModule = _ResolvedModule(
    typeKey: moduleTypeKey,
    displayName: moduleElement.displayName,
    moduleElement: moduleElement,
    importedModules: importedModules,
    importedProviders: importedProviders,
    providerInstantiations: providerInstantiations,
    controllerBindings: controllerBindings,
    exportedProviders: _resolveExportedProviders(
      annotationReader.read('exports'),
      moduleElement: moduleElement,
      importedModules: importedModules,
      importedProviders: importedProviders,
      localProviders: localProviders,
    ),
  );
  resolvedModules[moduleTypeKey] = resolvedModule;
  orderedModules.add(resolvedModule);
  return resolvedModule;
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

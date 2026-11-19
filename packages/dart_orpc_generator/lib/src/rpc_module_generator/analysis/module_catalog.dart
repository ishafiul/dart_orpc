part of '../../rpc_module_generator.dart';

/// Reads `@Module` annotations into the dependency layer's declarations.
///
/// Every declaration's `origin` is the analyzer element it came from, so
/// resolution errors point at the right source. Annotation problems, such as
/// a provider that is not a class, are reported here, as the resolver asks
/// for each module.
final class _AnalyzerModuleCatalog implements di.ModuleCatalog {
  _AnalyzerModuleCatalog(
    InterfaceElement rootModule, {
    required ConstantReader rootAnnotation,
  }) : rootKey = _typeKeyFor(rootModule.thisType) {
    _elements[rootKey] = rootModule;
    _annotations[rootKey] = rootAnnotation;
  }

  final String rootKey;
  final _elements = <String, InterfaceElement>{};
  final _annotations = <String, ConstantReader>{};
  final _headers = <String, di.ModuleHeader>{};
  final _definitions =
      Map<di.ProviderDeclaration, _ProviderDefinition>.identity();

  /// The analyzer-side definition [provider] was read from.
  _ProviderDefinition definitionOf(di.ProviderDeclaration provider) =>
      _definitions[provider]!;

  @override
  di.ModuleHeader header(String moduleKey) {
    final module = _elements[moduleKey]!;
    final annotation = _annotations.putIfAbsent(
      moduleKey,
      () => _readModuleAnnotation(module),
    );
    final imports = _readModuleElements(
      annotation.read('imports'),
      element: module,
      fieldName: 'imports',
    );
    final importKeys = [
      for (final imported in imports) _typeKeyFor(imported.thisType),
    ];
    for (final (index, imported) in imports.indexed) {
      _elements.putIfAbsent(importKeys[index], () => imported);
    }
    return _headers[moduleKey] = di.ModuleHeader(
      key: moduleKey,
      name: module.displayName,
      importKeys: importKeys,
      origin: module,
    );
  }

  @override
  di.ModuleDeclaration declaration(String moduleKey) {
    final module = _elements[moduleKey]!;
    final annotation = _annotations[moduleKey]!;
    final controllers = _readInterfaceElements(
      annotation.read('controllers'),
      element: module,
      fieldName: 'controllers',
    );
    final providers = _readProviderDefinitions(annotation, element: module);
    final exports = _readInterfaceElements(
      annotation.read('exports'),
      element: module,
      fieldName: 'exports',
    );
    return di.ModuleDeclaration(
      header: _headers[moduleKey]!,
      providers: [
        for (final provider in providers) _providerDeclaration(provider),
      ],
      controllers: [
        for (final controller in controllers)
          _controllerDeclaration(controller),
      ],
      exports: [
        for (final export in exports)
          di.ModuleExport(
            key: _typeKeyFor(export.thisType),
            name: export.displayName,
            isModule: _moduleChecker.hasAnnotationOfExact(export),
          ),
      ],
      isGlobal: annotation.read('global').boolValue,
    );
  }

  di.ProviderDeclaration _providerDeclaration(_ProviderDefinition provider) {
    final declaration = di.ProviderDeclaration(
      token: di.DependencyToken(
        key: provider.typeKey,
        typeName: provider.typeName,
        name: provider.tokenElement.displayName,
      ),
      parameters: [
        for (final parameter in provider.parameters)
          _dependencyParameter(parameter),
      ],
      origin: provider.providerElement,
    );
    _definitions[declaration] = provider;
    return declaration;
  }
}

di.ControllerDeclaration _controllerDeclaration(InterfaceElement controller) {
  final type = controller.thisType;
  return di.ControllerDeclaration(
    token: di.DependencyToken(
      key: _typeKeyFor(type),
      typeName: type.getDisplayString(),
      name: controller.displayName,
    ),
    parameters: [
      for (final parameter in _selectUnnamedConstructor(
        controller,
      ).formalParameters)
        _dependencyParameter(parameter),
    ],
    origin: controller,
  );
}

di.DependencyParameter _dependencyParameter(FormalParameterElement parameter) {
  final type = parameter.type;
  final element = type is InterfaceType ? type.element : null;
  return di.DependencyParameter(
    name: '${parameter.name}',
    kind: parameter.isRequiredPositional
        ? di.ParameterKind.requiredPositional
        : parameter.isOptionalPositional
        ? di.ParameterKind.optionalPositional
        : parameter.isRequiredNamed
        ? di.ParameterKind.requiredNamed
        : di.ParameterKind.optionalNamed,
    dependencyKey: _dependencyTypeKeyFor(type),
    externalType: element == null || element.displayName == 'Object'
        ? null
        : di.ExternalType(name: element.displayName, origin: element),
  );
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
  if (enclosingElement is InterfaceElement &&
      !factory.isStatic &&
      factory is! ConstructorElement) {
    throw InvalidGenerationSourceError(
      'Provider factory "${factory.displayName}" must be a top-level function, a static method, or a constructor.',
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

  final invocationTarget = switch ((factory, enclosingElement)) {
    (ConstructorElement(name: null || 'new'), final InterfaceElement owner) =>
      owner.displayName,
    (ConstructorElement(:final name?), final InterfaceElement owner) =>
      '${owner.displayName}.$name',
    (_, final InterfaceElement owner) =>
      '${owner.displayName}.${factory.displayName}',
    _ => factory.displayName,
  };
  return _ProviderDefinition(
    typeKey: _typeKeyFor(providedType),
    typeName: providedType.getDisplayString(),
    tokenElement: providedType.element,
    providerElement: factory,
    creationTarget: invocationTarget,
    parameters: factory.formalParameters,
  );
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

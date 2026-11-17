part of '../../rpc_module_generator.dart';

/// Resolves the module graph under [rootModule] for emission.
///
/// The dependency layer decides what the container holds and how each object
/// is built; this names every object and turns the result into the models the
/// emitters read. Controller procedures are analyzed here too, once each
/// module's injectable providers are known.
_ResolvedModuleGraph _resolveModuleGraph(
  InterfaceElement rootModule, {
  required ConstantReader annotation,
  required Set<String> usedNames,
  di.DependencyGraphResolver resolver = const di.ModuleDependencyResolver(),
}) {
  final catalog = _AnalyzerModuleCatalog(
    rootModule,
    rootAnnotation: annotation,
  );
  final di.ResolvedDependencyGraph graph;
  try {
    graph = resolver.resolve(catalog.rootKey, catalog);
  } on di.DependencyResolutionError catch (error) {
    throw InvalidGenerationSourceError(
      error.message,
      element: error.origin as Element?,
    );
  }

  final names = _containerVariableNames(graph, usedNames: usedNames);
  final resolvedModules = <String, _ResolvedModule>{};
  for (final scope in graph.modules) {
    final moduleElement = scope.declaration.origin! as InterfaceElement;
    final availableProviders = {
      for (final MapEntry(:key, :value) in scope.injectable.entries)
        key: names[value]!,
    };
    resolvedModules[scope.key] = _ResolvedModule(
      typeKey: scope.key,
      displayName: moduleElement.displayName,
      moduleElement: moduleElement,
      importedModules: [
        for (final imported in scope.imports) resolvedModules[imported.key]!,
      ],
      providerInstantiations: [
        for (final provider in scope.providers)
          _providerInstantiation(
            provider,
            catalog.definitionOf(provider.declaration),
            names,
          ),
      ],
      controllerBindings: [
        for (final controller in scope.controllers)
          _buildControllerBinding(
            controller.declaration.origin! as InterfaceElement,
            availableProviders: availableProviders,
            instanceName: names[controller.instance]!,
            instantiationCode: _constructionCode(
              names[controller.instance]!,
              creationTarget: controller.declaration.token.typeName,
              arguments: controller.arguments,
              names: names,
            ),
          ),
      ],
      externalProviderRequirements: [
        for (final requirement in scope.externalRequirements)
          _ExternalProviderRequirement(
            typeKey: requirement.instance.token.key,
            typeName: requirement.type.name,
            typeElement: requirement.type.origin! as InterfaceElement,
            variableName: names[requirement.instance]!,
          ),
      ],
    );
  }

  return _ResolvedModuleGraph(
    orderedModules: [
      for (final scope in graph.modules) resolvedModules[scope.key]!,
    ],
  );
}

/// A unique variable name for every object in the container.
///
/// Globally exported providers are named first, then each module's external
/// requirements, providers and controllers, in build order.
Map<di.InstanceRef, String> _containerVariableNames(
  di.ResolvedDependencyGraph graph, {
  required Set<String> usedNames,
}) {
  final names = <di.InstanceRef, String>{};
  String allocate(di.InstanceRef instance) =>
      _uniqueName(_lowerCamel(instance.token.name), usedNames);

  for (final instance in graph.globalExports) {
    names[instance] = allocate(instance);
  }
  for (final scope in graph.modules) {
    for (final requirement in scope.externalRequirements) {
      names[requirement.instance] = allocate(requirement.instance);
    }
    for (final provider in scope.providers) {
      names.putIfAbsent(provider.instance, () => allocate(provider.instance));
    }
    for (final controller in scope.controllers) {
      names[controller.instance] = allocate(controller.instance);
    }
  }
  return names;
}

_ResolvedInstantiation _providerInstantiation(
  di.ProviderConstruction construction,
  _ProviderDefinition definition,
  Map<di.InstanceRef, String> names,
) {
  final variableName = names[construction.instance]!;
  return _ResolvedInstantiation(
    typeKey: definition.typeKey,
    typeName: definition.typeName,
    variableName: variableName,
    providerElement: definition.providerElement,
    tokenElement: definition.tokenElement,
    code: _constructionCode(
      variableName,
      creationTarget: definition.creationTarget,
      arguments: construction.arguments,
      names: names,
    ),
  );
}

/// `final name = Target(positional..., named: ...);`
String _constructionCode(
  String variableName, {
  required String creationTarget,
  required List<di.ResolvedArgument> arguments,
  required Map<di.InstanceRef, String> names,
}) {
  final positional = [
    for (final argument in arguments)
      if (!argument.parameter.kind.isNamed) names[argument.instance]!,
  ];
  final named = [
    for (final argument in arguments)
      if (argument.parameter.kind.isNamed)
        '${argument.parameter.name}: ${names[argument.instance]!}',
  ];
  return 'final $variableName = $creationTarget(${[...positional, ...named].join(', ')});';
}

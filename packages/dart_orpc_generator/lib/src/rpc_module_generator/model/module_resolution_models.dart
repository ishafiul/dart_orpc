part of '../../rpc_module_generator.dart';

final class _ProviderDefinition {
  const _ProviderDefinition({
    required this.typeKey,
    required this.typeName,
    required this.tokenElement,
    required this.providerElement,
    required this.creationTarget,
    required this.parameters,
  });

  final String typeKey;
  final String typeName;
  final InterfaceElement tokenElement;
  final Element providerElement;
  final String creationTarget;
  final List<FormalParameterElement> parameters;
}

final class _ResolvedInstantiation {
  const _ResolvedInstantiation({
    required this.typeKey,
    required this.typeName,
    required this.variableName,
    required this.providerElement,
    required this.tokenElement,
    required this.code,
  });

  final String typeKey;
  final String typeName;
  final String variableName;
  final Element providerElement;
  final InterfaceElement tokenElement;
  final String code;
}

final class _ExternalProviderRequirement {
  const _ExternalProviderRequirement({
    required this.typeKey,
    required this.typeName,
    required this.typeElement,
    required this.variableName,
  });

  final String typeKey;
  final String typeName;
  final InterfaceElement typeElement;
  final String variableName;
}

final class _ResolvedModuleGraph {
  const _ResolvedModuleGraph({required this.orderedModules});

  final List<_ResolvedModule> orderedModules;

  _ResolvedModule get rootModule => orderedModules.last;
}

final class _ResolvedModule {
  const _ResolvedModule({
    required this.typeKey,
    required this.displayName,
    required this.moduleElement,
    required this.importedModules,
    required this.providerInstantiations,
    required this.controllerBindings,
    required this.externalProviderRequirements,
  });

  final String typeKey;
  final String displayName;
  final InterfaceElement moduleElement;
  final List<_ResolvedModule> importedModules;
  final List<_ResolvedInstantiation> providerInstantiations;
  final List<_ControllerBinding> controllerBindings;
  final List<_ExternalProviderRequirement> externalProviderRequirements;

  /// Every module this module imports, directly or transitively, each once.
  ///
  /// A module imported along several paths is one module with one set of
  /// providers, so compositions over the graph must visit it once. Modules
  /// come before the modules that import them.
  List<_ResolvedModule> get allImportedModules {
    final modules = <_ResolvedModule>[];
    final seenTypeKeys = <String>{typeKey};
    void visit(_ResolvedModule module) {
      for (final importedModule in module.importedModules) {
        if (seenTypeKeys.add(importedModule.typeKey)) {
          visit(importedModule);
          modules.add(importedModule);
        }
      }
    }

    visit(this);
    return modules;
  }

  List<_ControllerBinding> get allControllers {
    final controllers = <_ControllerBinding>[];
    final seenTypes = <String>{};
    for (final controller in [
      for (final importedModule in importedModules)
        ...importedModule.allControllers,
      ...controllerBindings,
    ]) {
      if (seenTypes.add(controller.typeName)) {
        controllers.add(controller);
      }
    }
    return controllers;
  }

  List<_ControllerBinding> get rpcCompatibleControllers => [
    for (final controller in allControllers)
      if (controller.rpcCompatibleProcedures.isNotEmpty) controller,
  ];
}

part of '../../rpc_module_generator.dart';

final class _ModuleDeclaration {
  const _ModuleDeclaration({
    required this.typeKey,
    required this.displayName,
    required this.moduleElement,
    required this.importedModules,
    required this.controllers,
    required this.providers,
    required this.exports,
    required this.isGlobal,
  });

  final String typeKey;
  final String displayName;
  final InterfaceElement moduleElement;
  final List<_ModuleDeclaration> importedModules;
  final List<InterfaceElement> controllers;
  final List<_ProviderDefinition> providers;
  final List<InterfaceElement> exports;
  final bool isGlobal;
}

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
  const _ResolvedModuleGraph({
    required this.orderedModules,
    required this.globalProviders,
  });

  final List<_ResolvedModule> orderedModules;
  final Map<String, _ResolvedProviderBinding> globalProviders;

  _ResolvedModule get rootModule => orderedModules.last;
}

final class _ResolvedModule {
  const _ResolvedModule({
    required this.typeKey,
    required this.displayName,
    required this.moduleElement,
    required this.importedModules,
    required this.importedProviders,
    required this.providerInstantiations,
    required this.controllerBindings,
    required this.exportedProviders,
    required this.isGlobal,
    required this.externalProviderRequirements,
  });

  final String typeKey;
  final String displayName;
  final InterfaceElement moduleElement;
  final List<_ResolvedModule> importedModules;
  final Map<String, _ResolvedProviderBinding> importedProviders;
  final List<_ResolvedInstantiation> providerInstantiations;
  final List<_ControllerBinding> controllerBindings;
  final Map<String, _ResolvedProviderBinding> exportedProviders;
  final bool isGlobal;
  final List<_ExternalProviderRequirement> externalProviderRequirements;

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

final class _ResolvedProviderBinding {
  const _ResolvedProviderBinding({
    required this.typeKey,
    required this.typeName,
    required this.variableName,
    required this.sourceLabel,
  });

  final String typeKey;
  final String typeName;
  final String variableName;
  final String sourceLabel;
}

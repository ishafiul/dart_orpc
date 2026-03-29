part of '../rpc_module_generator.dart';

final class _ResolvedInstantiation {
  const _ResolvedInstantiation({
    required this.typeKey,
    required this.typeName,
    required this.variableName,
    required this.providerElement,
    required this.code,
  });

  final String typeKey;
  final String typeName;
  final String variableName;
  final InterfaceElement providerElement;
  final String code;
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
    required this.importedProviders,
    required this.providerInstantiations,
    required this.controllerBindings,
    required this.exportedProviders,
  });

  final String typeKey;
  final String displayName;
  final InterfaceElement moduleElement;
  final List<_ResolvedModule> importedModules;
  final Map<String, _ResolvedProviderBinding> importedProviders;
  final List<_ResolvedInstantiation> providerInstantiations;
  final List<_ControllerBinding> controllerBindings;
  final Map<String, _ResolvedProviderBinding> exportedProviders;

  List<_ControllerBinding> get rpcCompatibleControllers => [
    for (final importedModule in importedModules)
      ...importedModule.rpcCompatibleControllers,
    for (final controller in controllerBindings)
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

final class _VisitedModule {
  const _VisitedModule({required this.typeKey, required this.displayName});

  final String typeKey;
  final String displayName;
}

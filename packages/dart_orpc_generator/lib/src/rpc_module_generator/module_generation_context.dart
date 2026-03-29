part of '../rpc_module_generator.dart';

_ModuleGenerationContext _buildModuleGenerationContext(
  InterfaceElement element, {
  required ConstantReader annotation,
}) {
  final usedNames = <String>{};
  final moduleGraph = _resolveModuleGraph(
    element,
    annotation: annotation,
    usedNames: usedNames,
  );
  final rootModule = moduleGraph.rootModule;
  final importedModules = rootModule.importedModules;
  final importedModulesWithRpcClients = importedModules
      .where((module) => module.rpcCompatibleControllers.isNotEmpty)
      .toList(growable: false);
  final rpcClientControllers = rootModule.controllerBindings
      .where((controller) => controller.rpcCompatibleProcedures.isNotEmpty)
      .toList(growable: false);
  final composedRpcClientGetters = _resolveComposedRpcClientGetters(
    rootModule,
    moduleElement: element,
  );

  return _ModuleGenerationContext(
    moduleName: element.displayName,
    rootModule: rootModule,
    importedModulesWithRpcClients: importedModulesWithRpcClients,
    importedProviderInstantiations: _collectImportedProviderInstantiationsForRoot(
      rootModule,
      rootModuleElement: element,
      annotation: annotation,
    ),
    rpcClientControllers: rpcClientControllers,
    hasLocalRpcClientControllers: rpcClientControllers.isNotEmpty,
    hasImportedRpcClientControllers: importedModulesWithRpcClients.isNotEmpty,
    needsTransportField: importedModulesWithRpcClients.isNotEmpty,
    composedRpcClientGetters: composedRpcClientGetters,
    generatedNames: _GeneratedModuleNames.forModule(
      element.displayName,
      reservedRootClientNames: {
        for (final getter in composedRpcClientGetters) getter.clientClassName,
      },
    ),
    openApiTitle: _openApiTitleFor(element.displayName),
    openApiSchemaComponents: _collectOpenApiSchemaComponents(
      rootModule.controllerBindings,
    ),
    containerMembers: [
      for (final instantiation in rootModule.providerInstantiations)
        _GeneratedContainerMember(
          typeName: instantiation.typeName,
          name: instantiation.variableName,
        ),
      for (final controller in rootModule.controllerBindings)
        _GeneratedContainerMember(
          typeName: controller.typeName,
          name: controller.instanceName,
        ),
    ],
  );
}

final class _ModuleGenerationContext {
  const _ModuleGenerationContext({
    required this.moduleName,
    required this.rootModule,
    required this.importedModulesWithRpcClients,
    required this.importedProviderInstantiations,
    required this.rpcClientControllers,
    required this.hasLocalRpcClientControllers,
    required this.hasImportedRpcClientControllers,
    required this.needsTransportField,
    required this.composedRpcClientGetters,
    required this.generatedNames,
    required this.openApiTitle,
    required this.openApiSchemaComponents,
    required this.containerMembers,
  });

  final String moduleName;
  final _ResolvedModule rootModule;
  final List<_ResolvedModule> importedModulesWithRpcClients;
  final List<_ResolvedInstantiation> importedProviderInstantiations;
  final List<_ControllerBinding> rpcClientControllers;
  final bool hasLocalRpcClientControllers;
  final bool hasImportedRpcClientControllers;
  final bool needsTransportField;
  final List<_ComposedRpcClientGetter> composedRpcClientGetters;
  final _GeneratedModuleNames generatedNames;
  final String openApiTitle;
  final List<_ResolvedOpenApiSchemaComponent> openApiSchemaComponents;
  final List<_GeneratedContainerMember> containerMembers;
}

part of '../../rpc_module_generator.dart';

final class _ModuleAnalyzer {
  const _ModuleAnalyzer();

  _ModuleGenerationPlan analyze(
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
    _validateUniqueProcedureContracts(rootModule, moduleElement: element);
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

    return _ModuleGenerationPlan(
      moduleName: element.displayName,
      rootModule: rootModule,
      importedModulesWithRpcClients: importedModulesWithRpcClients,
      importedProviderInstantiations:
          _collectImportedProviderInstantiationsForRoot(
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
}

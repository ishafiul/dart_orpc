part of '../../rpc_module_generator.dart';

/// Immutable handoff between source analysis and Dart code emission.
///
/// Analyzer API usage belongs in `analysis/`. Emitters consume this plan instead
/// of reading annotations or rebuilding the module graph.
final class _ModuleGenerationPlan {
  const _ModuleGenerationPlan({
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

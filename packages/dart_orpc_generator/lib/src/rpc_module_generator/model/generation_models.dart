part of '../../rpc_module_generator.dart';

final class _GeneratedModuleOutput {
  const _GeneratedModuleOutput({
    required this.code,
    required this.importDirectives,
    required this.exportDirectives,
  });

  final String code;
  final Set<String> importDirectives;
  final Set<String> exportDirectives;
}

final class _GeneratedModuleNames {
  const _GeneratedModuleNames({
    required this.rootClientName,
    required this.createRegistryName,
    required this.composeProcedureRegistryName,
    required this.createRestRouteRegistryName,
    required this.composeRestRouteRegistryName,
    required this.createMetadataRegistryName,
    required this.metadataRegistryName,
    required this.composeMetadataRegistryName,
    required this.createDtoSchemaRegistryName,
    required this.createLocalDtoSchemaRegistryName,
    required this.composeDtoSchemaRegistryName,
    required this.createOpenApiDocumentName,
    required this.composeOpenApiDocumentName,
    required this.containerClassName,
    required this.createContainerName,
    required this.createRegistryFromContainerName,
    required this.createRestRouteRegistryFromContainerName,
    required this.createRuntimeName,
    required this.composeRuntimeName,
    required this.buildAppName,
    required this.composeBuildAppName,
  });

  factory _GeneratedModuleNames.forModule(
    String moduleName, {
    required Set<String> reservedRootClientNames,
  }) {
    return _GeneratedModuleNames(
      rootClientName: _rootClientNameFor(
        moduleName,
        reservedNames: reservedRootClientNames,
      ),
      createRegistryName: '_\$create${moduleName}ProcedureRegistry',
      composeProcedureRegistryName: _publicProcedureRegistryFactoryNameFor(
        moduleName,
      ),
      createRestRouteRegistryName: '_\$create${moduleName}RestRouteRegistry',
      composeRestRouteRegistryName: _publicRestRouteRegistryFactoryNameFor(
        moduleName,
      ),
      createMetadataRegistryName:
          '_\$create${moduleName}ProcedureMetadataRegistry',
      metadataRegistryName:
          '_\$${moduleName[0].toLowerCase()}${moduleName.substring(1)}ProcedureMetadata',
      composeMetadataRegistryName:
          _publicProcedureMetadataRegistryFactoryNameFor(moduleName),
      createDtoSchemaRegistryName: '_\$create${moduleName}DtoSchemaRegistry',
      createLocalDtoSchemaRegistryName:
          '_\$create${moduleName}LocalDtoSchemaRegistry',
      composeDtoSchemaRegistryName: _publicDtoSchemaRegistryFactoryNameFor(
        moduleName,
      ),
      createOpenApiDocumentName: '_\$create${moduleName}OpenApiDocument',
      composeOpenApiDocumentName: _publicOpenApiDocumentFactoryNameFor(
        moduleName,
      ),
      containerClassName: '_\$${moduleName}Container',
      createContainerName: '_\$create${moduleName}Container',
      createRegistryFromContainerName:
          '_\$create${moduleName}ProcedureRegistryFromContainer',
      createRestRouteRegistryFromContainerName:
          '_\$create${moduleName}RestRouteRegistryFromContainer',
      createRuntimeName: '_\$create${moduleName}Runtime',
      composeRuntimeName: _publicModuleRuntimeFactoryNameFor(moduleName),
      buildAppName: '_\$build${moduleName}RpcApp',
      composeBuildAppName: _publicBuildAppFactoryNameFor(moduleName),
    );
  }

  final String rootClientName;
  final String createRegistryName;
  final String composeProcedureRegistryName;
  final String createRestRouteRegistryName;
  final String composeRestRouteRegistryName;
  final String createMetadataRegistryName;

  /// The module's one procedure metadata registry, built on first use and
  /// shared by the RPC registry, the REST routes and OpenAPI.
  final String metadataRegistryName;
  final String composeMetadataRegistryName;
  final String createDtoSchemaRegistryName;
  final String createLocalDtoSchemaRegistryName;
  final String composeDtoSchemaRegistryName;
  final String createOpenApiDocumentName;
  final String composeOpenApiDocumentName;
  final String containerClassName;
  final String createContainerName;
  final String createRegistryFromContainerName;
  final String createRestRouteRegistryFromContainerName;
  final String createRuntimeName;
  final String composeRuntimeName;
  final String buildAppName;
  final String composeBuildAppName;
}

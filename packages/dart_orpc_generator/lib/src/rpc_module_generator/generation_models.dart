part of '../rpc_module_generator.dart';

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
    required this.createLocalRegistryName,
    required this.composeProcedureRegistryName,
    required this.createRestRouteRegistryName,
    required this.createLocalRestRouteRegistryName,
    required this.composeRestRouteRegistryName,
    required this.createMetadataRegistryName,
    required this.createLocalMetadataRegistryName,
    required this.composeMetadataRegistryName,
    required this.createOpenApiSchemaRegistryName,
    required this.createLocalOpenApiSchemaRegistryName,
    required this.composeOpenApiSchemaRegistryName,
    required this.createOpenApiDocumentName,
    required this.composeOpenApiDocumentName,
    required this.containerClassName,
    required this.createContainerName,
    required this.createRegistryFromContainerName,
    required this.createRestRouteRegistryFromContainerName,
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
      createLocalRegistryName: '_\$create${moduleName}LocalProcedureRegistry',
      composeProcedureRegistryName: _publicProcedureRegistryFactoryNameFor(
        moduleName,
      ),
      createRestRouteRegistryName: '_\$create${moduleName}RestRouteRegistry',
      createLocalRestRouteRegistryName:
          '_\$create${moduleName}LocalRestRouteRegistry',
      composeRestRouteRegistryName: _publicRestRouteRegistryFactoryNameFor(
        moduleName,
      ),
      createMetadataRegistryName:
          '_\$create${moduleName}ProcedureMetadataRegistry',
      createLocalMetadataRegistryName:
          '_\$create${moduleName}LocalProcedureMetadataRegistry',
      composeMetadataRegistryName:
          _publicProcedureMetadataRegistryFactoryNameFor(moduleName),
      createOpenApiSchemaRegistryName:
          '_\$create${moduleName}OpenApiSchemaRegistry',
      createLocalOpenApiSchemaRegistryName:
          '_\$create${moduleName}LocalOpenApiSchemaRegistry',
      composeOpenApiSchemaRegistryName:
          _publicOpenApiSchemaRegistryFactoryNameFor(moduleName),
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
      buildAppName: '_\$build${moduleName}RpcApp',
      composeBuildAppName: _publicBuildAppFactoryNameFor(moduleName),
    );
  }

  final String rootClientName;
  final String createRegistryName;
  final String createLocalRegistryName;
  final String composeProcedureRegistryName;
  final String createRestRouteRegistryName;
  final String createLocalRestRouteRegistryName;
  final String composeRestRouteRegistryName;
  final String createMetadataRegistryName;
  final String createLocalMetadataRegistryName;
  final String composeMetadataRegistryName;
  final String createOpenApiSchemaRegistryName;
  final String createLocalOpenApiSchemaRegistryName;
  final String composeOpenApiSchemaRegistryName;
  final String createOpenApiDocumentName;
  final String composeOpenApiDocumentName;
  final String containerClassName;
  final String createContainerName;
  final String createRegistryFromContainerName;
  final String createRestRouteRegistryFromContainerName;
  final String buildAppName;
  final String composeBuildAppName;
}

part of '../../rpc_module_generator.dart';

final class _ModuleGenerationPipeline {
  const _ModuleGenerationPipeline();

  static const _analyzer = _ModuleAnalyzer();
  static const _emitter = _ModuleEmitter();

  Future<_GeneratedModuleOutput> generate(
    InterfaceElement element, {
    required ConstantReader annotation,
    required BuildStep buildStep,
  }) async {
    final context = _analyzer.analyze(element, annotation: annotation);
    var dtoSchemas = context.dtoSchemas;
    if (dtoSchemas.isNotEmpty) {
      final rootPackage = buildStep.inputId.package;
      final buildYamlByPackage = await _readDtoBuildYamls(
        buildStep,
        context.dtoSchemaPackages,
      );
      _rejectJsonFieldRename(
        element,
        rootPackage: rootPackage,
        buildYamlByPackage: buildYamlByPackage,
      );
      dtoSchemas = _resolveDtoUnknownKeys(
        element,
        dtoSchemas,
        rootPackage: rootPackage,
        unannotated: context.unannotatedDtoSchemas,
        buildYamlByPackage: buildYamlByPackage,
      );
    }
    final importDirectives = await _collectImportDirectivesForModule(
      context.rootModule,
      buildStep: buildStep,
      importedProviderInstantiations: context.importedProviderInstantiations,
      externalProviderRequirements: context.externalProviderRequirements,
    );
    final exportDirectives = await _collectExportDirectivesForModule(
      context.rootModule,
      buildStep: buildStep,
    );

    return _GeneratedModuleOutput(
      code: _emitter.emit(context, dtoSchemas: dtoSchemas),
      importDirectives: importDirectives,
      exportDirectives: exportDirectives,
    );
  }
}

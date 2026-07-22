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
    final importDirectives = await _collectImportDirectivesForModule(
      context.rootModule,
      buildStep: buildStep,
      importedProviderInstantiations: context.importedProviderInstantiations,
    );
    final exportDirectives = await _collectExportDirectivesForModule(
      context.rootModule,
      buildStep: buildStep,
    );

    return _GeneratedModuleOutput(
      code: _emitter.emit(context),
      importDirectives: importDirectives,
      exportDirectives: exportDirectives,
    );
  }
}

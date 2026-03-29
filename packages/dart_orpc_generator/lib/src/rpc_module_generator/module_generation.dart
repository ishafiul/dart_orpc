part of '../rpc_module_generator.dart';

Future<_GeneratedModuleOutput> _generateForModule(
  InterfaceElement element, {
  required ConstantReader annotation,
  required BuildStep buildStep,
}) async {
  final context = _buildModuleGenerationContext(
    element,
    annotation: annotation,
  );
  final buffer = StringBuffer();

  _writeContainerAndProcedureSections(buffer, context);
  _writeRestAndMetadataSections(buffer, context);
  _writeOpenApiSections(buffer, context);
  _writeClientSections(buffer, context);

  final importDirectives = await _collectImportDirectivesForModule(
    context.rootModule,
    buildStep: buildStep,
    importedProviderInstantiations: context.importedProviderInstantiations,
  );

  return _GeneratedModuleOutput(
    code: buffer.toString().trimRight(),
    importDirectives: importDirectives,
  );
}

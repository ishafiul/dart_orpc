part of '../../rpc_module_generator.dart';

/// Emits one module from a fully resolved generation context.
///
/// Keeping orchestration here makes the emission order explicit and gives new
/// output targets one obvious integration point.
final class _ModuleEmitter {
  const _ModuleEmitter();

  /// [dtoSchemas] are the plan's DTO schemas after build configuration,
  /// such as luthor's `unknown_keys` option, has been applied.
  String emit(
    _ModuleGenerationPlan context, {
    required List<DtoSchemaMetadata> dtoSchemas,
  }) {
    final buffer = StringBuffer();
    _writeContainerAndProcedureSections(buffer, context);
    _writeRestAndMetadataSections(buffer, context);
    _writeOpenApiSections(buffer, context);
    _writeDtoSchemaSections(buffer, context, dtoSchemas);
    _writeClientSections(buffer, context);
    return buffer.toString().trimRight();
  }
}

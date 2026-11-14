part of '../../rpc_module_generator.dart';

/// Schema metadata for the module's OpenAPI components and every DTO they
/// reference, keyed and sorted by component name.
List<DtoSchemaMetadata> _extractModuleDtoSchemas(
  List<_ResolvedOpenApiSchemaComponent> components,
) {
  final schemas = <String, DtoSchemaMetadata>{};
  final pending = <InterfaceElement>[
    for (final component in components) ?component.element,
  ];
  while (pending.isNotEmpty) {
    final element = pending.removeAt(0);
    if (schemas.containsKey(element.displayName)) continue;
    final extraction = extractDtoSchema(element);
    schemas[element.displayName] = extraction.schema;
    pending.addAll(extraction.references);
  }
  return schemas.values.toList(growable: false)
    ..sort((left, right) => left.name.compareTo(right.name));
}

/// Fails the build when the package configures json_serializable's
/// `field_rename` globally in `build.yaml`.
///
/// Wire names are derived from DTO annotations, which don't see builder
/// options, so a global rename would make the schema metadata wrong.
Future<void> _rejectGlobalJsonFieldRename(
  InterfaceElement module,
  BuildStep buildStep,
) async {
  final buildYaml = await _readPackageBuildYaml(buildStep);
  final rename = buildYaml == null ? null : globalJsonFieldRename(buildYaml);
  if (rename == null) return;
  throw InvalidGenerationSourceError(
    'build.yaml sets json_serializable field_rename: $rename globally. '
    'OpenAPI schema metadata reads wire names from DTO annotations, so use '
    '@JsonSerializable(fieldRename: ...) on each DTO instead.',
    element: module,
  );
}

/// The `build.yaml` of the package being built, if it exists.
///
/// build_runner only lets builders read a package's configured sources, and
/// `build.yaml` is not one by default, so fall back to reading it from disk.
/// build_runner restarts the build whenever `build.yaml` changes, so the
/// untracked read can't go stale.
Future<String?> _readPackageBuildYaml(BuildStep buildStep) async {
  final asset = AssetId(buildStep.inputId.package, 'build.yaml');
  if (await buildStep.canRead(asset)) return buildStep.readAsString(asset);
  final libraryRoot = await Isolate.resolvePackageUri(
    Uri.parse('package:${asset.package}/'),
  );
  if (libraryRoot == null || libraryRoot.scheme != 'file') return null;
  final file = File.fromUri(libraryRoot.resolve('../build.yaml'));
  return file.existsSync() ? file.readAsStringSync() : null;
}

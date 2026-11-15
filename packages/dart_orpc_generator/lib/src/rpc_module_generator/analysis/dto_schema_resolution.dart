part of '../../rpc_module_generator.dart';

/// Schema metadata for the module's OpenAPI components and every DTO they
/// reference, sorted by component name, plus the packages that own them.
///
/// Schemas whose `@Luthor` annotation sets no `unknownKeys` are listed in
/// `unannotated` with their owning package; [_resolveDtoUnknownKeys] applies
/// that package's builder option to them.
({
  List<DtoSchemaMetadata> schemas,
  Set<String> packages,
  Map<String, String?> unannotated,
})
_extractModuleDtoSchemas(List<_ResolvedOpenApiSchemaComponent> components) {
  final schemas = <String, DtoSchemaMetadata>{};
  final packages = <String>{};
  final unannotated = <String, String?>{};
  final pending = <InterfaceElement>[
    for (final component in components) ?component.element,
  ];
  while (pending.isNotEmpty) {
    final element = pending.removeAt(0);
    if (schemas.containsKey(element.displayName)) continue;
    final extraction = extractDtoSchema(element);
    schemas[element.displayName] = extraction.schema;
    final package = dtoOwningPackage(element);
    if (package != null) packages.add(package);
    if (extraction.annotatedUnknownKeys == null) {
      unannotated[element.displayName] = package;
    }
    pending.addAll(extraction.references);
  }
  return (
    schemas: schemas.values.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name)),
    packages: packages,
    unannotated: unannotated,
  );
}

/// [schemas] with luthor_generator's `unknown_keys` builder option applied
/// to the DTOs that don't annotate a mode, as luthor_generator applies it.
///
/// A DTO outside any package's `lib/` uses the root package's option.
List<DtoSchemaMetadata> _resolveDtoUnknownKeys(
  InterfaceElement module,
  List<DtoSchemaMetadata> schemas, {
  required String rootPackage,
  required Map<String, String?> unannotated,
  required Map<String, String?> buildYamlByPackage,
}) {
  try {
    return applyLuthorUnknownKeys(
      schemas,
      rootPackage: rootPackage,
      unannotated: unannotated,
      buildYamlByPackage: buildYamlByPackage,
    );
  } on LuthorUnknownKeysConfigException catch (error) {
    throw InvalidGenerationSourceError(error.message, element: module);
  }
}

/// The `build.yaml` of the module's package and of every package that owns
/// one of its DTOs.
Future<Map<String, String?>> _readDtoBuildYamls(
  BuildStep buildStep,
  Set<String> dtoPackages,
) async {
  final rootPackage = buildStep.inputId.package;
  return {
    for (final package in {rootPackage, ...dtoPackages})
      package: await _readPackageBuildYaml(buildStep, package),
  };
}

/// Fails the build when json_serializable's `field_rename` is configured in
/// a `build.yaml` that applies to the module's DTOs: the root package's
/// `global_options`, or the `targets` of any package that owns one of them.
///
/// Wire names are derived from DTO annotations, which don't see builder
/// options, so such a rename would make the schema metadata wrong.
void _rejectJsonFieldRename(
  InterfaceElement module, {
  required String rootPackage,
  required Map<String, String?> buildYamlByPackage,
}) {
  final violation = findJsonFieldRename(
    rootPackage: rootPackage,
    buildYamlByPackage: buildYamlByPackage,
  );
  if (violation == null) return;
  final (:package, :rename, :source) = violation;
  throw InvalidGenerationSourceError(
    'The build.yaml of package "$package" sets json_serializable '
    'field_rename: $rename in $source, which applies to DTOs this module '
    'uses. OpenAPI schema metadata reads wire names from DTO annotations, '
    'so use @JsonSerializable(fieldRename: ...) on each DTO instead.',
    element: module,
  );
}

/// The `build.yaml` of [package], if it exists.
///
/// build_runner only lets builders read a package's configured sources, and
/// `build.yaml` is not one by default, so fall back to reading it from disk.
/// That read isn't tracked: a change to the root package's `build.yaml`
/// re-runs this builder (verified with `build_runner watch`), but a change to
/// a dependency's `build.yaml` is only seen on the next build_runner start,
/// like other dependency changes.
Future<String?> _readPackageBuildYaml(
  BuildStep buildStep,
  String package,
) async {
  final asset = AssetId(package, 'build.yaml');
  if (await buildStep.canRead(asset)) return buildStep.readAsString(asset);
  final libraryRoot = await Isolate.resolvePackageUri(
    Uri.parse('package:$package/'),
  );
  if (libraryRoot == null || libraryRoot.scheme != 'file') return null;
  final file = File.fromUri(libraryRoot.resolve('../build.yaml'));
  return file.existsSync() ? file.readAsStringSync() : null;
}

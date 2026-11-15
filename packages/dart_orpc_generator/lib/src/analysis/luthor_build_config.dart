import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:yaml/yaml.dart';

const _luthorBuilderKeys = {
  'luthor_generator:luthor',
  'luthor_generator|luthor',
};

const _unknownKeysOption = 'unknown_keys';

/// A luthor_generator `unknown_keys` option that can't be followed.
final class LuthorUnknownKeysConfigException implements Exception {
  const LuthorUnknownKeysConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The luthor_generator `unknown_keys` builder option for DTOs owned by
/// [package], defaulting to [DtoUnknownKeys.strip].
///
/// [buildYamlByPackage] maps package names to their `build.yaml` contents,
/// or `null` when a package has none. Options combine as build_runner
/// combines them: [package]'s target `options`, then its `dev_options` or
/// `release_options`, then the [rootPackage]'s `global_options` and their
/// own `dev_options` or `release_options`, each overriding the last.
///
/// Throws a [LuthorUnknownKeysConfigException] when the value is not a mode,
/// or when targets or build modes disagree on the effective mode.
DtoUnknownKeys findLuthorUnknownKeys({
  required String rootPackage,
  required String package,
  required Map<String, String?> buildYamlByPackage,
}) {
  final global = _globalBuilderConfig(buildYamlByPackage[rootPackage]);
  final targets = _load(buildYamlByPackage[package])?['targets'];
  final targetConfigs = targets is YamlMap && targets.isNotEmpty
      ? targets.entries
      : const [MapEntry(r'$default', null)];
  final modesByTarget = <Object?, DtoUnknownKeys>{};
  for (final MapEntry(:key, :value) in targetConfigs) {
    final target = _luthorConfigIn(value is YamlMap ? value['builders'] : null);
    modesByTarget[key] = _resolveMode(global, target, package, key);
  }
  final modes = modesByTarget.values.toSet();
  if (modes.length == 1) return modes.single;

  final conflictingTargets = modesByTarget.entries
      .map((entry) => '${entry.key}: ${entry.value.name}')
      .join(', ');
  throw LuthorUnknownKeysConfigException(
    'luthor_generator unknown_keys for package "$package" differs across '
    'build targets ($conflictingTargets). Use the same mode across targets, '
    'or set @Luthor(unknownKeys: ...) on each DTO.',
  );
}

DtoUnknownKeys _resolveMode(
  YamlMap? global,
  YamlMap? target,
  String package,
  Object? targetName,
) {
  Object resolve(String modeSection) {
    final options = {
      ...?_options(target, 'options'),
      ...?_options(target, modeSection),
      ...?_options(global, 'options'),
      ...?_options(global, modeSection),
    };
    return options[_unknownKeysOption] ?? DtoUnknownKeys.strip.name;
  }

  final dev = resolve('dev_options');
  final release = resolve('release_options');
  if (dev != release) {
    throw LuthorUnknownKeysConfigException(
      'luthor_generator unknown_keys for package "$package", target '
      '"$targetName", is "$dev" in '
      'development builds but "$release" in release builds. Use the same '
      'mode in both, or set @Luthor(unknownKeys: ...) on each DTO.',
    );
  }
  for (final mode in DtoUnknownKeys.values) {
    if (mode.name == dev) return mode;
  }
  throw LuthorUnknownKeysConfigException(
    'luthor_generator unknown_keys for package "$package", target '
    '"$targetName", is "$dev"; it must be one of '
    '${DtoUnknownKeys.values.map((mode) => mode.name).join(', ')}.',
  );
}

/// [schemas] with each owning package's `unknown_keys` option applied to the
/// DTOs named in [unannotated], whose `@Luthor` sets no mode.
///
/// [unannotated] maps those DTO names to their owning package, or `null`
/// for DTOs outside any package's `lib/`, which use [rootPackage]'s option.
/// Schemas with an explicit annotation keep their mode.
/// Throws what [findLuthorUnknownKeys] throws.
List<DtoSchemaMetadata> applyLuthorUnknownKeys(
  List<DtoSchemaMetadata> schemas, {
  required String rootPackage,
  required Map<String, String?> unannotated,
  required Map<String, String?> buildYamlByPackage,
}) {
  final modeByPackage = <String, DtoUnknownKeys>{};
  DtoUnknownKeys modeFor(String package) => modeByPackage.putIfAbsent(
    package,
    () => findLuthorUnknownKeys(
      rootPackage: rootPackage,
      package: package,
      buildYamlByPackage: buildYamlByPackage,
    ),
  );

  return [
    for (final schema in schemas)
      switch (unannotated.containsKey(schema.name)
          ? modeFor(unannotated[schema.name] ?? rootPackage)
          : null) {
        final mode? when mode != schema.unknownKeys => DtoSchemaMetadata(
          name: schema.name,
          fields: schema.fields,
          unknownKeys: mode,
        ),
        _ => schema,
      },
  ];
}

YamlMap? _globalBuilderConfig(String? buildYaml) =>
    _luthorConfigIn(_load(buildYaml)?['global_options']);

YamlMap? _luthorConfigIn(Object? builders) {
  if (builders is! YamlMap) return null;
  for (final MapEntry(:key, :value) in builders.entries) {
    if (_luthorBuilderKeys.contains(key) && value is YamlMap) return value;
  }
  return null;
}

YamlMap? _options(YamlMap? config, String section) {
  final options = config?[section];
  return options is YamlMap ? options : null;
}

YamlMap? _load(String? buildYaml) {
  if (buildYaml == null) return null;
  try {
    final config = loadYaml(buildYaml);
    return config is YamlMap ? config : null;
  } on YamlException {
    return null;
  }
}

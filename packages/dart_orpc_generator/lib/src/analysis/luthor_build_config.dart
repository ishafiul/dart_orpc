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
/// [package], or `null` when none is set and luthor strips unknown keys.
///
/// [buildYamlByPackage] maps package names to their `build.yaml` contents,
/// or `null` when a package has none. Options combine as build_runner
/// combines them: [package]'s target `options`, then its `dev_options` or
/// `release_options`, then the [rootPackage]'s `global_options` and their
/// own `dev_options` or `release_options`, each overriding the last.
///
/// Throws a [LuthorUnknownKeysConfigException] when the value is not a mode,
/// or when development and release builds would use different modes, since
/// one set of generated metadata can't describe both.
DtoUnknownKeys? findLuthorUnknownKeys({
  required String rootPackage,
  required String package,
  required Map<String, String?> buildYamlByPackage,
}) {
  final target = _targetBuilderConfig(buildYamlByPackage[package]);
  final global = _globalBuilderConfig(buildYamlByPackage[rootPackage]);

  Object? resolve(String modeSection) =>
      _option(global, modeSection) ??
      _option(global, 'options') ??
      _option(target, modeSection) ??
      _option(target, 'options');

  final dev = resolve('dev_options');
  final release = resolve('release_options');
  if (dev != release) {
    throw LuthorUnknownKeysConfigException(
      'luthor_generator unknown_keys for package "$package" is "$dev" in '
      'development builds but "$release" in release builds. Use the same '
      'mode in both, or set @Luthor(unknownKeys: ...) on each DTO.',
    );
  }
  if (dev == null) return null;
  for (final mode in DtoUnknownKeys.values) {
    if (mode.name == dev) return mode;
  }
  throw LuthorUnknownKeysConfigException(
    'luthor_generator unknown_keys for package "$package" is "$dev"; it must '
    'be one of ${DtoUnknownKeys.values.map((mode) => mode.name).join(', ')}.',
  );
}

/// [schemas] with each owning package's `unknown_keys` option applied to the
/// DTOs named in [unannotated], whose `@Luthor` sets no mode.
///
/// [unannotated] maps those DTO names to their owning package, or `null`
/// for DTOs outside any package's `lib/`, which use [rootPackage]'s option.
/// Other schemas, and DTOs whose package sets no option, are unchanged.
/// Throws what [findLuthorUnknownKeys] throws.
List<DtoSchemaMetadata> applyLuthorUnknownKeys(
  List<DtoSchemaMetadata> schemas, {
  required String rootPackage,
  required Map<String, String?> unannotated,
  required Map<String, String?> buildYamlByPackage,
}) {
  final modeByPackage = <String, DtoUnknownKeys?>{};
  DtoUnknownKeys? modeFor(String package) => modeByPackage.putIfAbsent(
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

/// The luthor builder's entry in the first target of [buildYaml] that
/// configures it.
YamlMap? _targetBuilderConfig(String? buildYaml) {
  final targets = _load(buildYaml)?['targets'];
  if (targets is! YamlMap) return null;
  for (final target in targets.values) {
    final builders = target is YamlMap ? target['builders'] : null;
    final config = _luthorConfigIn(builders);
    if (config != null) return config;
  }
  return null;
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

Object? _option(YamlMap? config, String section) {
  final options = config?[section];
  return options is YamlMap ? options[_unknownKeysOption] : null;
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

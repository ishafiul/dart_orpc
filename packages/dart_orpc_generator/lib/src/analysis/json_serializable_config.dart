import 'package:yaml/yaml.dart';

const _jsonSerializableBuilderKeys = {
  'json_serializable',
  'json_serializable:json_serializable',
  'json_serializable|json_serializable',
};

const _optionSections = ['options', 'dev_options', 'release_options'];

/// A json_serializable `field_rename` set outside DTO annotations.
typedef JsonFieldRenameViolation = ({
  String package,
  String rename,
  String source,
});

/// The `field_rename` a package's own `build.yaml` targets give
/// json_serializable, or `null` when there is none, it is `none`, or the
/// file is not valid YAML.
String? targetJsonFieldRename(String buildYaml) {
  final config = _load(buildYaml);
  final targets = config?['targets'];
  if (targets is! YamlMap) return null;
  for (final target in targets.values) {
    final builders = target is YamlMap ? target['builders'] : null;
    final rename = _renameIn(builders);
    if (rename != null) return rename;
  }
  return null;
}

/// The `field_rename` the root package's `global_options` give
/// json_serializable in every package of the build.
String? globalOptionsJsonFieldRename(String buildYaml) =>
    _renameIn(_load(buildYaml)?['global_options']);

/// The first json_serializable `field_rename` that applies to a module's DTOs.
///
/// [buildYamlByPackage] maps the module's package ([rootPackage]) and every
/// package that owns one of its DTOs to that package's `build.yaml`
/// contents, or `null` when it has none. The root's `global_options` apply to
/// every package; each package's `targets` apply to the DTOs it owns.
JsonFieldRenameViolation? findJsonFieldRename({
  required String rootPackage,
  required Map<String, String?> buildYamlByPackage,
}) {
  final rootYaml = buildYamlByPackage[rootPackage];
  if (rootYaml != null) {
    final rename = globalOptionsJsonFieldRename(rootYaml);
    if (rename != null) {
      return (package: rootPackage, rename: rename, source: 'global_options');
    }
  }
  final packages = buildYamlByPackage.keys.toList()..sort();
  for (final package in packages) {
    final yaml = buildYamlByPackage[package];
    final rename = yaml == null ? null : targetJsonFieldRename(yaml);
    if (rename != null) {
      return (package: package, rename: rename, source: 'targets');
    }
  }
  return null;
}

YamlMap? _load(String buildYaml) {
  try {
    final config = loadYaml(buildYaml);
    return config is YamlMap ? config : null;
  } on YamlException {
    return null;
  }
}

String? _renameIn(Object? builders) {
  if (builders is! YamlMap) return null;
  for (final MapEntry(:key, :value) in builders.entries) {
    if (!_jsonSerializableBuilderKeys.contains(key)) continue;
    if (value is! YamlMap) continue;
    // build_config merges dev_options or release_options over options, so a
    // rename in any of them applies in some build mode.
    for (final section in _optionSections) {
      final options = value[section];
      final rename = options is YamlMap ? options['field_rename'] : null;
      if (rename != null && rename != 'none') return '$rename';
    }
  }
  return null;
}

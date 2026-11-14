import 'package:yaml/yaml.dart';

const _jsonSerializableBuilderKeys = {
  'json_serializable',
  'json_serializable:json_serializable',
  'json_serializable|json_serializable',
};

/// The `field_rename` json_serializable applies to every class in a package,
/// read from that package's `build.yaml` contents.
///
/// Returns `null` when no global rename is configured, it is `none`, or the
/// file is not valid YAML.
String? globalJsonFieldRename(String buildYaml) {
  final Object? config;
  try {
    config = loadYaml(buildYaml);
  } on YamlException {
    return null;
  }
  if (config is! YamlMap) return null;
  final targets = config['targets'];
  if (targets is! YamlMap) return null;
  for (final target in targets.values) {
    final builders = target is YamlMap ? target['builders'] : null;
    if (builders is! YamlMap) continue;
    for (final MapEntry(:key, :value) in builders.entries) {
      if (!_jsonSerializableBuilderKeys.contains(key)) continue;
      final options = value is YamlMap ? value['options'] : null;
      final rename = options is YamlMap ? options['field_rename'] : null;
      if (rename != null && rename != 'none') return '$rename';
    }
  }
  return null;
}

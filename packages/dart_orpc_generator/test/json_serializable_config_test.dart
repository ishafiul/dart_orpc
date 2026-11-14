import 'package:dart_orpc_generator/src/analysis/json_serializable_config.dart';
import 'package:test/test.dart';

const _targetsSnake = '''
targets:
  \$default:
    builders:
      json_serializable:
        options:
          field_rename: snake
''';

const _globalOptionsKebab = '''
global_options:
  json_serializable:json_serializable:
    options:
      field_rename: kebab
''';

const _clean = '''
targets:
  \$default:
    builders:
      json_serializable:
        options:
          explicit_to_json: true
      drift_dev:
        options:
          field_rename: snake
''';

void main() {
  group('Given a build.yaml', () {
    test('When json_serializable sets field_rename then it is returned', () {
      expect(targetJsonFieldRename(_targetsSnake), 'snake');
    });

    test('When the builder uses its full key then field_rename is found', () {
      expect(
        targetJsonFieldRename('''
targets:
  \$default:
    builders:
      json_serializable:json_serializable:
        options:
          field_rename: kebab
'''),
        'kebab',
      );
    });

    test('When global_options sets field_rename then it is returned', () {
      expect(globalOptionsJsonFieldRename(_globalOptionsKebab), 'kebab');
      expect(targetJsonFieldRename(_globalOptionsKebab), isNull);
    });

    test('When a target sets field_rename per build mode then it is '
        'returned', () {
      for (final mode in ['dev_options', 'release_options']) {
        expect(
          targetJsonFieldRename('''
targets:
  \$default:
    builders:
      json_serializable:
        $mode:
          field_rename: snake
'''),
          'snake',
          reason: mode,
        );
      }
    });

    test('When global_options set field_rename per build mode then it is '
        'returned', () {
      for (final mode in ['dev_options', 'release_options']) {
        expect(
          globalOptionsJsonFieldRename('''
global_options:
  json_serializable:
    $mode:
      field_rename: pascal
'''),
          'pascal',
          reason: mode,
        );
      }
    });

    test('When field_rename is none then nothing is returned', () {
      expect(
        targetJsonFieldRename('''
targets:
  \$default:
    builders:
      json_serializable:
        options:
          field_rename: none
'''),
        isNull,
      );
    });

    test(
      'When json_serializable has other options then nothing is returned',
      () {
        expect(targetJsonFieldRename(_clean), isNull);
        expect(globalOptionsJsonFieldRename(_clean), isNull);
      },
    );

    test('When the file is empty or invalid then nothing is returned', () {
      for (final yaml in [
        '',
        'targets: [unclosed',
        'targets:\n  \$default: 3\n',
      ]) {
        expect(targetJsonFieldRename(yaml), isNull);
        expect(globalOptionsJsonFieldRename(yaml), isNull);
      }
    });
  });

  group('Given the build.yaml of each package a module uses', () {
    test('When the root package sets global_options then it is reported', () {
      expect(
        findJsonFieldRename(
          rootPackage: 'app',
          buildYamlByPackage: {'app': _globalOptionsKebab, 'models': _clean},
        ),
        (package: 'app', rename: 'kebab', source: 'global_options'),
      );
    });

    test('When a DTO package sets field_rename for its target then it is '
        'reported', () {
      expect(
        findJsonFieldRename(
          rootPackage: 'app',
          buildYamlByPackage: {'app': _clean, 'models': _targetsSnake},
        ),
        (package: 'models', rename: 'snake', source: 'targets'),
      );
    });

    test('When only a dependency sets global_options then it is ignored', () {
      expect(
        findJsonFieldRename(
          rootPackage: 'app',
          buildYamlByPackage: {'app': _clean, 'models': _globalOptionsKebab},
        ),
        isNull,
      );
    });

    test('When a package has no build.yaml then it is skipped', () {
      expect(
        findJsonFieldRename(
          rootPackage: 'app',
          buildYamlByPackage: {'app': null, 'models': null},
        ),
        isNull,
      );
    });
  });
}

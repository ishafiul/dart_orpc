import 'package:dart_orpc_generator/src/analysis/json_serializable_config.dart';
import 'package:test/test.dart';

void main() {
  group('Given a build.yaml', () {
    test('When json_serializable sets field_rename then it is returned', () {
      expect(
        globalJsonFieldRename('''
targets:
  \$default:
    builders:
      json_serializable:
        options:
          field_rename: snake
'''),
        'snake',
      );
    });

    test('When the builder uses its full key then field_rename is found', () {
      expect(
        globalJsonFieldRename('''
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

    test('When field_rename is none then nothing is returned', () {
      expect(
        globalJsonFieldRename('''
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
        expect(
          globalJsonFieldRename('''
targets:
  \$default:
    builders:
      json_serializable:
        options:
          explicit_to_json: true
      drift_dev:
        options:
          field_rename: snake
'''),
          isNull,
        );
      },
    );

    test('When the file is empty or invalid then nothing is returned', () {
      expect(globalJsonFieldRename(''), isNull);
      expect(globalJsonFieldRename('targets: [unclosed'), isNull);
      expect(globalJsonFieldRename('targets:\n  \$default: 3\n'), isNull);
    });
  });
}

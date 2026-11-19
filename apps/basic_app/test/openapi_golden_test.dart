import 'dart:convert';
import 'dart:io';

import 'package:basic_app/basic_app.dart';
import 'package:test/test.dart';

const _goldenPath = 'test/goldens/openapi.json';
const _updateGoldensCommand =
    'UPDATE_GOLDENS=1 dart test test/openapi_golden_test.dart';
const _maxReportedDifferences = 50;

void main() {
  group('Given the basic_app OpenAPI document', () {
    late Object? document;

    setUp(() {
      document = jsonDecode(
        jsonEncode(
          const AppModule().openApiDocument(options: basicAppOpenApiOptions),
        ),
      );
    });

    test('When compared with the golden snapshot then it matches', () {
      final golden = File(_goldenPath);
      if (Platform.environment['UPDATE_GOLDENS'] == '1') {
        golden
          ..createSync(recursive: true)
          ..writeAsStringSync(_sortedIndentedJson(document));
      }

      final differences = _jsonDifferences(
        jsonDecode(golden.readAsStringSync()),
        document,
      );

      expect(
        differences,
        isEmpty,
        reason:
            'The OpenAPI document differs from $_goldenPath. If the change '
            'is intended, review it and run: $_updateGoldensCommand\n'
            '${differences.join('\n')}',
      );
    });
  });

  group('Given two JSON documents', () {
    test('When key order differs then they are equal', () {
      expect(_jsonDifferences({'a': 1, 'b': 2}, {'b': 2, 'a': 1}), isEmpty);
    });

    test('When list order differs then it is reported', () {
      expect(_jsonDifferences([1, 2], [2, 1]), [
        r'$[0]: expected 1, actual 2',
        r'$[1]: expected 2, actual 1',
      ]);
    });

    test('When a nested value differs then its path is reported', () {
      expect(
        _jsonDifferences(
          {
            'components': {
              'schemas': {
                'Dto': {'minLength': 1},
              },
            },
          },
          {
            'components': {
              'schemas': {
                'Dto': {'minLength': 2},
              },
            },
          },
        ),
        [r'$.components.schemas.Dto.minLength: expected 1, actual 2'],
      );
    });

    test('When many keys differ then at most 50 are reported', () {
      expect(
        _jsonDifferences(<String, Object?>{}, {
          for (var index = 0; index < 100; index++) 'key$index': index,
        }),
        hasLength(_maxReportedDifferences),
      );
    });

    test('When keys or list items differ then each is reported', () {
      expect(
        _jsonDifferences(
          {
            'required': ['id'],
            'gone': true,
          },
          {
            'required': ['id', 'name'],
            'added': true,
          },
        ),
        [
          r'$.added: unexpected key',
          r'$.gone: missing key',
          r'$.required: expected 1 items, actual 2',
        ],
      );
    });
  });
}

String _sortedIndentedJson(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(_sorted(value))}\n';

Object? _sorted(Object? value) => switch (value) {
  Map() => {
    for (final key in (value.keys.map((key) => '$key').toList()..sort()))
      key: _sorted(value[key]),
  },
  List() => [for (final item in value) _sorted(item)],
  _ => value,
};

List<String> _jsonDifferences(Object? expected, Object? actual) {
  final differences = <String>[];

  void visit(String path, Object? expected, Object? actual) {
    if (differences.length >= _maxReportedDifferences) return;
    if (expected is Map && actual is Map) {
      final keys = {...expected.keys, ...actual.keys}.map((k) => '$k').toList()
        ..sort();
      for (final key in keys) {
        if (differences.length >= _maxReportedDifferences) return;
        final childPath = '$path.$key';
        if (!expected.containsKey(key)) {
          differences.add('$childPath: unexpected key');
        } else if (!actual.containsKey(key)) {
          differences.add('$childPath: missing key');
        } else {
          visit(childPath, expected[key], actual[key]);
        }
      }
      return;
    }
    if (expected is List && actual is List) {
      if (expected.length != actual.length) {
        differences.add(
          '$path: expected ${expected.length} items, actual ${actual.length}',
        );
        return;
      }
      for (var index = 0; index < expected.length; index++) {
        visit('$path[$index]', expected[index], actual[index]);
      }
      return;
    }
    if (expected != actual) {
      differences.add(
        '$path: expected ${jsonEncode(expected)}, actual ${jsonEncode(actual)}',
      );
    }
  }

  visit(r'$', expected, actual);
  return differences;
}

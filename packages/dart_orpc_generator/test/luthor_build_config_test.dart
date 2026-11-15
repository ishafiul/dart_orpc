import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_generator/src/analysis/luthor_build_config.dart';
import 'package:test/test.dart';

const _root = 'app';
const _dependency = 'shared_dtos';

String _target(String sections) => '''
targets:
  \$default:
    builders:
      luthor_generator:luthor:
$sections''';

String _global(String sections) => '''
global_options:
  luthor_generator:luthor:
$sections''';

DtoUnknownKeys _find(
  Map<String, String?> buildYamlByPackage, {
  String package = _root,
}) => findLuthorUnknownKeys(
  rootPackage: _root,
  package: package,
  buildYamlByPackage: buildYamlByPackage,
);

void main() {
  _applyTests();

  group('Given build.yaml files without the luthor option', () {
    test('When resolved then strip applies by default', () {
      expect(_find({_root: null}), DtoUnknownKeys.strip);
      expect(_find({_root: 'targets: {}'}), DtoUnknownKeys.strip);
      expect(_find({_root: ': not yaml ['}), DtoUnknownKeys.strip);
    });
  });

  group('Given a target option', () {
    test('When resolved for its package then it applies', () {
      final mode = _find({
        _root: _target('        options:\n          unknown_keys: strict\n'),
      });

      expect(mode, DtoUnknownKeys.strict);
    });

    test('When the builder key uses the pipe form then it applies', () {
      final mode = _find({
        _root:
            'targets:\n  \$default:\n    builders:\n'
            '      luthor_generator|luthor:\n'
            '        options:\n          unknown_keys: passthrough\n',
      });

      expect(mode, DtoUnknownKeys.passthrough);
    });

    test('When it belongs to another package then it does not apply', () {
      final mode = _find({
        _root: null,
        _dependency: _target(
          '        options:\n          unknown_keys: strict\n',
        ),
      });

      expect(mode, DtoUnknownKeys.strip);
    });
  });

  group('Given disjoint build targets', () {
    const targets = '''
targets:
  \$default:
    sources: [lib/strict/**]
    builders:
      luthor_generator:luthor:
        options:
          unknown_keys: strict
  other:
    sources: [lib/other/**]
''';

    test('When their effective modes differ then resolution fails', () {
      expect(
        () => _find({_root: targets}),
        throwsA(
          isA<LuthorUnknownKeysConfigException>().having(
            (error) => error.message,
            'message',
            contains(r'build targets ($default: strict, other: strip)'),
          ),
        ),
      );
    });

    test('When a root option makes both modes agree then it applies', () {
      final mode = _find({
        _root:
            '$targets${_global('    options:\n      unknown_keys: passthrough\n')}',
      });

      expect(mode, DtoUnknownKeys.passthrough);
    });
  });

  group('Given root global_options', () {
    test('When resolved for a dependency then they apply', () {
      final mode = _find({
        _root: _global('    options:\n      unknown_keys: strict\n'),
        _dependency: null,
      }, package: _dependency);

      expect(mode, DtoUnknownKeys.strict);
    });

    test('When a target sets another mode then global_options win', () {
      final mode = _find({
        _root: _global('    options:\n      unknown_keys: strict\n'),
        _dependency: _target(
          '        options:\n          unknown_keys: passthrough\n',
        ),
      }, package: _dependency);

      expect(mode, DtoUnknownKeys.strict);
    });

    test('When a global option clears a target mode then strip applies', () {
      final mode = _find({
        _root: _global('    options:\n      unknown_keys: null\n'),
        _dependency: _target(
          '        options:\n          unknown_keys: strict\n',
        ),
      }, package: _dependency);

      expect(mode, DtoUnknownKeys.strip);
    });

    test('When a dependency sets global_options then they are ignored', () {
      final mode = _find({
        _root: null,
        _dependency: _global('    options:\n      unknown_keys: strict\n'),
      }, package: _dependency);

      expect(mode, DtoUnknownKeys.strip);
    });
  });

  group('Given dev_options and release_options', () {
    test('When only development sets strip then both modes agree', () {
      final mode = _find({
        _root: _target('        dev_options:\n          unknown_keys: strip\n'),
      });

      expect(mode, DtoUnknownKeys.strip);
    });

    test('When both override options alike then that mode applies', () {
      final mode = _find({
        _root: _target(
          '        options:\n          unknown_keys: strip\n'
          '        dev_options:\n          unknown_keys: strict\n'
          '        release_options:\n          unknown_keys: strict\n',
        ),
      });

      expect(mode, DtoUnknownKeys.strict);
    });

    test('When they differ then resolution fails', () {
      expect(
        () => _find({
          _root: _target(
            '        dev_options:\n          unknown_keys: strict\n',
          ),
        }),
        throwsA(
          isA<LuthorUnknownKeysConfigException>().having(
            (error) => error.message,
            'message',
            contains('"strict" in development builds but "strip" in release'),
          ),
        ),
      );
    });
  });

  group('Given an unknown mode', () {
    test('When resolved then it fails naming the value', () {
      expect(
        () => _find({
          _root: _target('        options:\n          unknown_keys: lenient\n'),
        }),
        throwsA(
          isA<LuthorUnknownKeysConfigException>().having(
            (error) => error.toString(),
            'message',
            contains('is "lenient"; it must be one of strip, passthrough'),
          ),
        ),
      );
    });
  });
}

void _applyTests() {
  const strip = DtoSchemaMetadata(name: 'UnannotatedDto', fields: []);
  const annotated = DtoSchemaMetadata(
    name: 'AnnotatedDto',
    fields: [],
    unknownKeys: DtoUnknownKeys.passthrough,
  );
  const fixture = DtoSchemaMetadata(name: 'FixtureDto', fields: []);
  final strictTarget = _target(
    '        options:\n          unknown_keys: strict\n',
  );

  group('Given schemas and package options', () {
    test('When applied then unannotated DTOs take their package mode', () {
      final schemas = applyLuthorUnknownKeys(
        [strip, annotated, fixture],
        rootPackage: _root,
        unannotated: {'UnannotatedDto': _dependency, 'FixtureDto': null},
        buildYamlByPackage: {_root: strictTarget, _dependency: strictTarget},
      );

      expect(
        [for (final schema in schemas) schema.unknownKeys],
        [
          DtoUnknownKeys.strict,
          DtoUnknownKeys.passthrough,
          DtoUnknownKeys.strict,
        ],
      );
    });

    test('When no package sets a mode then schemas are unchanged', () {
      final schemas = applyLuthorUnknownKeys(
        [strip, annotated],
        rootPackage: _root,
        unannotated: {'UnannotatedDto': _root},
        buildYamlByPackage: {_root: null},
      );

      expect(schemas[0], same(strip));
      expect(schemas[1], same(annotated));
    });
  });
}

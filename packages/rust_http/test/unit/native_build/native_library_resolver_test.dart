import 'dart:io';

import 'package:rust_http/src/native_build/cargo_build_source.dart';
import 'package:rust_http/src/native_build/local_cargo_target_source.dart';
import 'package:rust_http/src/native_build/native_build_context.dart';
import 'package:rust_http/src/native_build/native_library_resolver.dart';
import 'package:rust_http/src/native_build/native_library_source.dart';
import 'package:rust_http/src/native_build/user_defined_library_source.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late NativeBuildContext host;

  setUp(() {
    root = Directory.systemTemp.createTempSync('rust_http_build_');
    Directory('${root.path}/native/src').createSync(recursive: true);
    host = NativeBuildContext(
      packageRoot: root.uri.resolve('./'),
      libraryFileName: 'librust_http.dylib',
      isHostTarget: true,
      sharedOutputDirectory: root.uri.resolve('out/'),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  File touch(String relative) => File('${root.path}/$relative')
    ..createSync(recursive: true)
    ..writeAsStringSync('x');

  group('NativeLibraryResolver', () {
    test('returns the first source that finds a library', () async {
      final resolver = NativeLibraryResolver([
        _FixedSource(null),
        _FixedSource(LocatedLibrary(Uri.file('/a'))),
        _FixedSource(LocatedLibrary(Uri.file('/b'))),
      ]);

      final found = await resolver.resolve(host);

      expect(found?.file, Uri.file('/a'));
    });

    test('returns null when no source finds a library', () async {
      final resolver = NativeLibraryResolver([_FixedSource(null)]);

      expect(await resolver.resolve(host), isNull);
    });
  });

  group('UserDefinedLibrarySource', () {
    test('is skipped without a user define', () async {
      expect(await const UserDefinedLibrarySource().locate(host), isNull);
    });

    test('returns the configured file', () async {
      final file = touch('custom/librust_http.dylib');
      final context = host.copyWith(userLibraryPath: file.path);

      final found = await const UserDefinedLibrarySource().locate(context);

      expect(found?.file, file.absolute.uri);
    });

    test('throws when the configured file does not exist', () {
      final context = host.copyWith(userLibraryPath: '${root.path}/missing');

      expect(
        () => const UserDefinedLibrarySource().locate(context),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('LocalCargoTargetSource', () {
    test('finds a release build in native/target', () async {
      touch('native/target/release/librust_http.dylib');

      final found = await const LocalCargoTargetSource().locate(host);

      expect(
        found?.file.path,
        endsWith('native/target/release/librust_http.dylib'),
      );
    });

    test('is skipped when cross compiling', () async {
      touch('native/target/release/librust_http.dylib');
      final context = host.copyWith(isHostTarget: false);

      expect(await const LocalCargoTargetSource().locate(context), isNull);
    });
  });

  group('CargoBuildSource', () {
    test('builds with cargo and reports the sources as dependencies', () async {
      touch('native/Cargo.toml');
      touch('native/Cargo.lock');
      touch('native/src/lib.rs');
      final calls = <List<String>>[];
      final source = CargoBuildSource(
        runProcess: (executable, arguments) async {
          calls.add([executable, ...arguments]);
          touch('out/cargo/release/librust_http.dylib');
          return ProcessResult(0, 0, '', '');
        },
      );

      final found = await source.locate(host);

      expect(calls.single, containsAllInOrder(['build', '--release']));
      expect(
        found?.file.path,
        endsWith('out/cargo/release/librust_http.dylib'),
      );
      expect(
        found?.dependencies.map((uri) => uri.pathSegments.last),
        containsAll(['Cargo.toml', 'Cargo.lock', 'lib.rs']),
      );
    });

    test('returns null when cargo fails', () async {
      final source = CargoBuildSource(
        runProcess: (_, _) async => ProcessResult(0, 101, '', 'boom'),
        log: (_) {},
      );

      expect(await source.locate(host), isNull);
    });

    test('returns null when cargo is not installed', () async {
      final source = CargoBuildSource(
        runProcess: (executable, _) =>
            throw ProcessException(executable, const []),
      );

      expect(await source.locate(host), isNull);
    });

    test('is skipped when cross compiling', () async {
      var ran = false;
      final source = CargoBuildSource(
        runProcess: (_, _) async {
          ran = true;
          return ProcessResult(0, 0, '', '');
        },
      );

      await source.locate(host.copyWith(isHostTarget: false));

      expect(ran, isFalse);
    });
  });
}

final class _FixedSource implements NativeLibrarySource {
  _FixedSource(this._result);

  final LocatedLibrary? _result;

  @override
  Future<LocatedLibrary?> locate(NativeBuildContext context) async => _result;
}

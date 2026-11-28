import 'package:rust_http/src/ffi/fallback_library.dart';
import 'package:test/test.dart';

void main() {
  group('fallbackLibraryCandidates', () {
    List<String> candidates({
      Map<String, String> environment = const {},
      String script = 'file:///srv/app/bin/server.aot',
      String executable = '/usr/lib/dart/bin/dartaotruntime',
      String operatingSystem = 'linux',
    }) => fallbackLibraryCandidates(
      environment: environment,
      script: Uri.parse(script),
      executable: executable,
      operatingSystem: operatingSystem,
    );

    test('tries lib/ and ../lib/ beside the script, then the executable', () {
      expect(candidates(), [
        '/srv/app/bin/lib/librust_http.so',
        '/srv/app/lib/librust_http.so',
        '/usr/lib/dart/bin/lib/librust_http.so',
        '/usr/lib/dart/lib/librust_http.so',
      ]);
    });

    test('tries RUST_HTTP_LIB first', () {
      expect(
        candidates(environment: {'RUST_HTTP_LIB': '/opt/librust_http.so'}),
        [
          '/opt/librust_http.so',
          '/srv/app/bin/lib/librust_http.so',
          '/srv/app/lib/librust_http.so',
          '/usr/lib/dart/bin/lib/librust_http.so',
          '/usr/lib/dart/lib/librust_http.so',
        ],
      );
    });

    test('ignores an empty RUST_HTTP_LIB', () {
      expect(
        candidates(environment: {'RUST_HTTP_LIB': ''}),
        isNot(contains('')),
      );
    });

    test('lists a directory once when script and executable share it', () {
      final paths = candidates(
        script: 'file:///srv/app/bin/server',
        executable: '/srv/app/bin/server',
      );

      expect(paths, [
        '/srv/app/bin/lib/librust_http.so',
        '/srv/app/lib/librust_http.so',
      ]);
    });

    test('skips a script that is not a file', () {
      expect(
        candidates(script: 'package:app/main.dart'),
        everyElement(startsWith('/usr/lib/dart/')),
      );
    });

    test('uses the macOS file name on macOS', () {
      expect(
        candidates(operatingSystem: 'macos'),
        everyElement(endsWith('librust_http.dylib')),
      );
    });

    test('has no candidates where global loading is unsupported', () {
      expect(candidates(operatingSystem: 'windows'), isEmpty);
    });
  });

  group('prefixedLibraryFiles', () {
    test('keeps target-prefixed library names, sorted', () {
      expect(
        prefixedLibraryFiles([
          '/app/lib/linux-x64-librust_http.so',
          '/app/lib/libdartaotserver.so',
          '/app/lib/linux-arm64-librust_http.so',
          '/app/lib/librust_http.so.bak',
        ], 'librust_http.so'),
        [
          '/app/lib/linux-arm64-librust_http.so',
          '/app/lib/linux-x64-librust_http.so',
        ],
      );
    });

    test('ignores the plain name, which is matched exactly instead', () {
      expect(
        prefixedLibraryFiles(['/app/lib/librust_http.so'], 'librust_http.so'),
        isEmpty,
      );
    });
  });
}

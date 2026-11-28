import 'dart:ffi';

import 'package:rust_http/src/ffi/native_library.dart';
import 'package:test/test.dart';

void main() {
  group('NativeLibraryLoader', () {
    test('loads when the ABI matches and init succeeds', () {
      final loader = NativeLibraryLoader(
        readAbiVersion: () => NativeLibraryLoader.expectedAbiVersion,
        initialize: (_) => 0,
      );

      expect(loader.load(), isA<NativeLibraryLoaded>());
    });

    test('refuses a library with another ABI version', () {
      final loader = NativeLibraryLoader(
        readAbiVersion: () => NativeLibraryLoader.expectedAbiVersion + 1,
        initialize: (_) => fail('must not initialize'),
      );

      final status = loader.load();

      expect(
        status,
        isA<NativeLibraryUnavailable>().having(
          (s) => s.reason,
          'reason',
          contains('ABI'),
        ),
      );
    });

    test('reports a failed init with its code', () {
      final loader = NativeLibraryLoader(
        readAbiVersion: () => NativeLibraryLoader.expectedAbiVersion,
        initialize: (_) => -3,
      );

      expect(
        loader.load(),
        isA<NativeLibraryUnavailable>().having(
          (s) => s.reason,
          'reason',
          contains('-3'),
        ),
      );
    });

    test('reports a missing library instead of throwing', () {
      final loader = NativeLibraryLoader(
        readAbiVersion: () => throw ArgumentError('Couldn\'t resolve native'),
        initialize: (_) => 0,
        fallbackLibraries: () => const [],
      );

      expect(loader.load(), isA<NativeLibraryUnavailable>());
    });

    group('without a bundled library', () {
      test('loads a fallback library globally and retries', () {
        final loaded = <String>[];
        final loader = NativeLibraryLoader(
          readAbiVersion: () => loaded.isEmpty
              ? throw ArgumentError('No asset found')
              : NativeLibraryLoader.expectedAbiVersion,
          initialize: (_) => 0,
          fallbackLibraries: () => ['/app/lib/librust_http.so'],
          loadGlobally: (path) {
            loaded.add(path);
            return null;
          },
        );

        expect(loader.load(), isA<NativeLibraryLoaded>());
        expect(loaded, ['/app/lib/librust_http.so']);
      });

      test('skips a library that fails to load and tries the next', () {
        final loaded = <String>[];
        final loader = NativeLibraryLoader(
          readAbiVersion: () => loaded.isEmpty
              ? throw ArgumentError('No asset found')
              : NativeLibraryLoader.expectedAbiVersion,
          initialize: (_) => 0,
          fallbackLibraries: () => ['/missing.so', '/app/lib/librust_http.so'],
          loadGlobally: (path) {
            if (path == '/missing.so') return 'image not found';
            loaded.add(path);
            return null;
          },
        );

        expect(loader.load(), isA<NativeLibraryLoaded>());
        expect(loaded, ['/app/lib/librust_http.so']);
      });

      test('reports every failed attempt with the original error', () {
        final loader = NativeLibraryLoader(
          readAbiVersion: () => throw ArgumentError('No asset found'),
          initialize: (_) => fail('must not initialize'),
          fallbackLibraries: () => ['/a.so', '/b.so'],
          loadGlobally: (path) => 'cannot open $path',
        );

        expect(
          loader.load(),
          isA<NativeLibraryUnavailable>().having(
            (s) => s.reason,
            'reason',
            allOf(
              contains('No asset found'),
              contains('/a.so: cannot open /a.so'),
              contains('/b.so: cannot open /b.so'),
            ),
          ),
        );
      });

      test('reports a loaded library whose symbols still do not resolve', () {
        final loader = NativeLibraryLoader(
          readAbiVersion: () => throw ArgumentError('No asset found'),
          initialize: (_) => fail('must not initialize'),
          fallbackLibraries: () => ['/other.so'],
          loadGlobally: (_) => null,
        );

        expect(
          loader.load(),
          isA<NativeLibraryUnavailable>().having(
            (s) => s.reason,
            'reason',
            contains('/other.so loaded, but'),
          ),
        );
      });

      test('still checks the ABI of a fallback library', () {
        var loaded = false;
        final loader = NativeLibraryLoader(
          readAbiVersion: () => loaded
              ? NativeLibraryLoader.expectedAbiVersion + 1
              : throw ArgumentError('No asset found'),
          initialize: (_) => fail('must not initialize'),
          fallbackLibraries: () => ['/old/librust_http.so'],
          loadGlobally: (_) {
            loaded = true;
            return null;
          },
        );

        expect(
          loader.load(),
          isA<NativeLibraryUnavailable>().having(
            (s) => s.reason,
            'reason',
            contains('ABI'),
          ),
        );
      });

      test('does not look for a fallback when the bundled library loads', () {
        final loader = NativeLibraryLoader(
          readAbiVersion: () => NativeLibraryLoader.expectedAbiVersion,
          initialize: (_) => 0,
          fallbackLibraries: () => fail('must not look for a fallback'),
        );

        expect(loader.load(), isA<NativeLibraryLoaded>());
      });
    });

    test('loads once and caches the status', () {
      var reads = 0;
      final loader = NativeLibraryLoader(
        readAbiVersion: () {
          reads++;
          return NativeLibraryLoader.expectedAbiVersion;
        },
        initialize: (Pointer<Void> _) => 0,
      );

      loader.status;
      loader.status;

      expect(reads, 1);
    });

    test('ensureAvailable throws an UnsupportedError with the reason', () {
      final loader = NativeLibraryLoader(
        readAbiVersion: () => 0,
        initialize: (_) => 0,
      );

      expect(
        loader.ensureAvailable,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(contains('ABI'), contains('cargo')),
          ),
        ),
      );
    });
  });
}

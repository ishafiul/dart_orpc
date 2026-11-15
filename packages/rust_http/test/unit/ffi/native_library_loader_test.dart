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
      );

      expect(loader.load(), isA<NativeLibraryUnavailable>());
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

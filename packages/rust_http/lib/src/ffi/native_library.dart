import 'dart:ffi';

import 'bindings.dart';
import 'fallback_library.dart';

/// Whether the native library could be used.
sealed class NativeLibraryStatus {
  const NativeLibraryStatus();
}

/// The library is loaded, has the expected ABI and is connected to the VM.
final class NativeLibraryLoaded extends NativeLibraryStatus {
  /// Creates the status.
  const NativeLibraryLoaded();
}

/// The library cannot be used, for [reason].
final class NativeLibraryUnavailable extends NativeLibraryStatus {
  /// Creates the status.
  const NativeLibraryUnavailable(this.reason);

  /// Why the library cannot be used.
  final String reason;
}

/// Loads the native library once and remembers the result.
final class NativeLibraryLoader {
  /// Creates a loader. The functions default to the real FFI bindings and
  /// are replaceable for tests.
  ///
  /// When the bundled library cannot be resolved, [fallbackLibraries] lists
  /// library files to try instead and [loadGlobally] loads one, returning
  /// null on success or why it failed. See `fallback_library.dart`.
  NativeLibraryLoader({
    int Function()? readAbiVersion,
    int Function(Pointer<Void>)? initialize,
    List<String> Function()? fallbackLibraries,
    String? Function(String path)? loadGlobally,
  }) : _readAbiVersion = readAbiVersion ?? rustHttpAbiVersion,
       _initialize = initialize ?? rustHttpInit,
       _fallbackLibraries = fallbackLibraries ?? existingFallbackLibraries,
       _loadGlobally = loadGlobally ?? loadLibraryGlobally;

  /// The ABI version this Dart code speaks. Must equal `ABI_VERSION` in
  /// `native/src/lib.rs`.
  static const int expectedAbiVersion = 4;

  final int Function() _readAbiVersion;
  final int Function(Pointer<Void>) _initialize;
  final List<String> Function() _fallbackLibraries;
  final String? Function(String path) _loadGlobally;
  NativeLibraryStatus? _status;

  /// The load result. The first call loads the library.
  NativeLibraryStatus get status => _status ??= load();

  /// Loads the library now, without caching.
  NativeLibraryStatus load() {
    final int version;
    try {
      version = _readAbiVersion();
    } on Object catch (error) {
      // No build hook bundled the library (e.g. `dart compile aot-snapshot`).
      final fallback = _loadFallback();
      if (fallback case (final int found, _)) {
        return _checkAndInitialize(found);
      }
      final attempts = fallback.$2;
      return NativeLibraryUnavailable(
        attempts.isEmpty ? '$error' : '$error; ${attempts.join('; ')}',
      );
    }
    return _checkAndInitialize(version);
  }

  /// Loads the first fallback library that loads and reads its ABI version.
  /// Returns the version, or null and what each attempt reported.
  (int?, List<String>) _loadFallback() {
    final attempts = <String>[];
    for (final path in _fallbackLibraries()) {
      final failure = _loadGlobally(path);
      if (failure != null) {
        attempts.add('$path: $failure');
        continue;
      }
      try {
        return (_readAbiVersion(), attempts);
      } on Object catch (error) {
        // Loaded, but its symbols still do not resolve: not our library.
        attempts.add('$path loaded, but $error');
        return (null, attempts);
      }
    }
    return (null, attempts);
  }

  NativeLibraryStatus _checkAndInitialize(int version) {
    if (version != expectedAbiVersion) {
      return NativeLibraryUnavailable(
        'native library ABI $version, expected $expectedAbiVersion',
      );
    }
    final code = _initialize(NativeApi.initializeApiDLData);
    if (code != 0) {
      return NativeLibraryUnavailable('rust_http_init failed ($code)');
    }
    return const NativeLibraryLoaded();
  }

  /// Throws an [UnsupportedError] that explains why the library is not
  /// available and how to fix it. Does nothing when it is.
  void ensureAvailable() {
    if (status case NativeLibraryUnavailable(:final reason)) {
      throw UnsupportedError(
        'rust_http did not load: $reason.\n'
        'Fix: install Rust (cargo, see https://rustup.rs), then run the app '
        'again with `dart run`, `dart test` or `dart build cli`; the build '
        'hook then builds the library from source. If you set `lib_path` in '
        'pubspec.yaml, rebuild that library with `cargo build --release` in '
        'packages/rust_http/native. Programs from `dart compile '
        'aot-snapshot` or `dart compile exe` run no build hooks: put the '
        'library in a `lib/` folder beside the program, or set '
        '$rustHttpLibEnvironmentKey to its path (macOS and Linux).',
      );
    }
  }
}

/// The process-wide loader.
final NativeLibraryLoader nativeLibrary = NativeLibraryLoader();

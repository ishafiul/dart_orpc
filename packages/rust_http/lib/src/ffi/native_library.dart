import 'dart:ffi';

import 'bindings.dart';

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
  NativeLibraryLoader({
    int Function()? readAbiVersion,
    int Function(Pointer<Void>)? initialize,
  }) : _readAbiVersion = readAbiVersion ?? rustHttpAbiVersion,
       _initialize = initialize ?? rustHttpInit;

  /// The ABI version this Dart code speaks. Must equal `ABI_VERSION` in
  /// `native/src/lib.rs`.
  static const int expectedAbiVersion = 1;

  final int Function() _readAbiVersion;
  final int Function(Pointer<Void>) _initialize;
  NativeLibraryStatus? _status;

  /// The load result. The first call loads the library.
  NativeLibraryStatus get status => _status ??= load();

  /// Loads the library now, without caching.
  NativeLibraryStatus load() {
    final int version;
    try {
      version = _readAbiVersion();
    } on Object catch (error) {
      // No library was bundled for this platform.
      return NativeLibraryUnavailable('$error');
    }
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
        'packages/rust_http/native.',
      );
    }
  }
}

/// The process-wide loader.
final NativeLibraryLoader nativeLibrary = NativeLibraryLoader();

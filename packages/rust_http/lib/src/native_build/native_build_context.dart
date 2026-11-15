/// What a [NativeLibrarySource] needs to know about the current build.
///
/// It is a plain value, independent of `package:hooks`, so sources can be
/// tested without a real build.
library;

import 'native_library_source.dart' show NativeLibrarySource;

/// The build being run by the hook.
final class NativeBuildContext {
  /// Creates a build context.
  const NativeBuildContext({
    required this.packageRoot,
    required this.libraryFileName,
    required this.isHostTarget,
    required this.sharedOutputDirectory,
    this.userLibraryPath,
  });

  /// Root of the `rust_http` package, ending in `/`.
  final Uri packageRoot;

  /// File name of the library on the target OS, e.g. `librust_http.so`.
  final String libraryFileName;

  /// Whether the target OS and CPU are those of the machine running the
  /// build. Only then can a local or freshly built library be used.
  final bool isHostTarget;

  /// Directory shared between builds, for cached build outputs.
  final Uri sharedOutputDirectory;

  /// The `lib_path` user define from the app's `pubspec.yaml`, if any.
  final String? userLibraryPath;

  /// The Rust crate.
  Uri get nativeRoot => packageRoot.resolve('native/');

  /// A copy with the given fields replaced.
  NativeBuildContext copyWith({bool? isHostTarget, String? userLibraryPath}) {
    return NativeBuildContext(
      packageRoot: packageRoot,
      libraryFileName: libraryFileName,
      isHostTarget: isHostTarget ?? this.isHostTarget,
      sharedOutputDirectory: sharedOutputDirectory,
      userLibraryPath: userLibraryPath ?? this.userLibraryPath,
    );
  }
}

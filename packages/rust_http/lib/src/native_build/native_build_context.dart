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
    required this.targetName,
    required this.isHostTarget,
    required this.sharedOutputDirectory,
    this.userLibraryPath,
    this.usePrebuilt = true,
  });

  /// Root of the `rust_http` package, ending in `/`.
  final Uri packageRoot;

  /// File name of the library on the target OS, e.g. `librust_http.so`.
  final String libraryFileName;

  /// Target OS and CPU, e.g. `linux-x64` or `macos-arm64`.
  final String targetName;

  /// Whether the target OS and CPU are those of the machine running the
  /// build. Only then can a local or freshly built library be used.
  final bool isHostTarget;

  /// Directory shared between builds, for cached build outputs.
  final Uri sharedOutputDirectory;

  /// The `lib_path` user define from the app's `pubspec.yaml`, if any.
  final String? userLibraryPath;

  /// Whether a prebuilt library may be downloaded. False when the app sets
  /// the `prebuilt: false` user define.
  final bool usePrebuilt;

  /// The Rust crate.
  Uri get nativeRoot => packageRoot.resolve('native/');

  /// A copy with the given fields replaced.
  NativeBuildContext copyWith({
    String? targetName,
    bool? isHostTarget,
    String? userLibraryPath,
    bool? usePrebuilt,
  }) {
    return NativeBuildContext(
      packageRoot: packageRoot,
      libraryFileName: libraryFileName,
      targetName: targetName ?? this.targetName,
      isHostTarget: isHostTarget ?? this.isHostTarget,
      sharedOutputDirectory: sharedOutputDirectory,
      userLibraryPath: userLibraryPath ?? this.userLibraryPath,
      usePrebuilt: usePrebuilt ?? this.usePrebuilt,
    );
  }
}

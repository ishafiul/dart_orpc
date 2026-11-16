import 'native_build_context.dart';

/// One way to obtain the native library, such as a local build or a
/// download.
abstract interface class NativeLibrarySource {
  /// The library for [context], or null when this source has none.
  ///
  /// Throws only for a configuration error the user must fix; a source that
  /// merely cannot help returns null so the next one is tried.
  Future<LocatedLibrary?> locate(NativeBuildContext context);
}

/// A native library found by a [NativeLibrarySource].
final class LocatedLibrary {
  /// Creates a located library.
  const LocatedLibrary(this.file, {this.dependencies = const []});

  /// The library file.
  final Uri file;

  /// Files whose change must rebuild the library.
  final List<Uri> dependencies;
}

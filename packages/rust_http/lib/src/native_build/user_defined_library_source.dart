import 'dart:io';

import 'native_build_context.dart';
import 'native_library_source.dart';

/// A library the user built themselves, set in the app's `pubspec.yaml`:
///
/// ```yaml
/// hooks:
///   user_defines:
///     rust_http:
///       lib_path: /path/to/librust_http.so
/// ```
final class UserDefinedLibrarySource implements NativeLibrarySource {
  /// Creates the source.
  const UserDefinedLibrarySource();

  @override
  Future<LocatedLibrary?> locate(NativeBuildContext context) async {
    final path = context.userLibraryPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('rust_http: lib_path $path does not exist.');
    }
    return LocatedLibrary(file.absolute.uri, dependencies: [file.absolute.uri]);
  }
}

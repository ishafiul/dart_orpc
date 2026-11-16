import 'dart:io';

import 'native_build_context.dart';
import 'native_library_source.dart';

/// A release build already in `native/target/release`, for development.
final class LocalCargoTargetSource implements NativeLibrarySource {
  /// Creates the source.
  const LocalCargoTargetSource();

  @override
  Future<LocatedLibrary?> locate(NativeBuildContext context) async {
    if (!context.isHostTarget) return null;
    final library = context.nativeRoot.resolve(
      'target/release/${context.libraryFileName}',
    );
    if (!File.fromUri(library).existsSync()) return null;
    return LocatedLibrary(library, dependencies: [library]);
  }
}

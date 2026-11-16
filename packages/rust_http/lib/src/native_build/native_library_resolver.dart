import 'cargo_build_source.dart';
import 'local_cargo_target_source.dart';
import 'native_build_context.dart';
import 'native_library_source.dart';
import 'prebuilt_download_source.dart';
import 'user_defined_library_source.dart';

/// Tries [NativeLibrarySource]s in order and returns the first library
/// found.
final class NativeLibraryResolver {
  /// Creates a resolver over [sources], tried in order.
  const NativeLibraryResolver(this.sources);

  /// The default order: the user's own library, then a local release build,
  /// then a prebuilt download, then a fresh `cargo build`.
  factory NativeLibraryResolver.standard({void Function(String)? log}) {
    return NativeLibraryResolver([
      const UserDefinedLibrarySource(),
      const LocalCargoTargetSource(),
      PrebuiltDownloadSource(log: log),
      CargoBuildSource(log: log),
    ]);
  }

  /// The sources, in the order they are tried.
  final List<NativeLibrarySource> sources;

  /// The first library found for [context], or null.
  Future<LocatedLibrary?> resolve(NativeBuildContext context) async {
    for (final source in sources) {
      final library = await source.locate(context);
      if (library != null) return library;
    }
    return null;
  }
}

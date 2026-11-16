/// A GitHub release of prebuilt rust_http native libraries.
final class PrebuiltRelease {
  /// Creates a release description.
  const PrebuiltRelease({
    required this.tag,
    required this.fingerprint,
    required this.sha256ByAsset,
  });

  /// Repository the release belongs to.
  static const repository = 'ishafiul/dart_orpc';

  /// The release tag, `rust_http-native-<fingerprint prefix>`.
  final String tag;

  /// The `NativeSourceFingerprint` of the sources the libraries were built
  /// from.
  final String fingerprint;

  /// SHA-256 in hex of each release asset, keyed by [assetName].
  final Map<String, String> sha256ByAsset;

  /// The release tag for sources with [fingerprint].
  static String tagFor(String fingerprint) =>
      'rust_http-native-${fingerprint.substring(0, 16)}';

  /// The asset name for a target, e.g. `linux-x64-librust_http.so`.
  static String assetName(String targetName, String libraryFileName) =>
      '$targetName-$libraryFileName';

  /// Download URL of [asset] in this release.
  Uri assetUri(String asset) =>
      Uri.https('github.com', '/$repository/releases/download/$tag/$asset');
}

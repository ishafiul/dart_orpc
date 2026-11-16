import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'native_build_context.dart';
import 'native_library_source.dart';
import 'native_source_fingerprint.dart';
import 'prebuilt_manifest.dart' as manifest;
import 'prebuilt_release.dart';

/// Downloads a file, writing it to a destination.
typedef FileDownloader = Future<void> Function(Uri uri, File destination);

/// A prebuilt library downloaded from the GitHub release in
/// `prebuilt_manifest.dart`, so building an app does not need Rust.
///
/// The download is used only when the package's Rust sources match the
/// release fingerprint and the file matches its committed SHA-256. It is
/// cached in the shared build output, so it is fetched once per release.
/// Any failure returns null, falling back to building from source.
final class PrebuiltDownloadSource implements NativeLibrarySource {
  /// Creates the source for [release], which defaults to the one this
  /// package version was published with. [download] and [log] are
  /// replaceable for tests.
  PrebuiltDownloadSource({
    PrebuiltRelease? release = manifest.prebuiltRelease,
    FileDownloader? download,
    void Function(String)? log,
  }) : _release = release,
       _download = download ?? _httpDownload,
       _log = log ?? stderr.writeln;

  final PrebuiltRelease? _release;
  final FileDownloader _download;
  final void Function(String) _log;

  @override
  Future<LocatedLibrary?> locate(NativeBuildContext context) async {
    final release = _release;
    if (release == null || !context.usePrebuilt) return null;

    final asset = PrebuiltRelease.assetName(
      context.targetName,
      context.libraryFileName,
    );
    final expectedHash = release.sha256ByAsset[asset];
    if (expectedHash == null) return null;

    final sources = NativeSourceFingerprint.sourceFiles(context.nativeRoot);
    final dependencies = [for (final file in sources) file.absolute.uri];
    if (NativeSourceFingerprint.compute(context.nativeRoot) !=
        release.fingerprint) {
      // The Rust sources were changed locally; build them instead.
      return null;
    }

    final directory = Directory.fromUri(
      context.sharedOutputDirectory.resolve('prebuilt/${release.tag}/'),
    );
    final library = File.fromUri(directory.uri.resolve(asset));
    if (library.existsSync() && await _sha256(library) == expectedHash) {
      return LocatedLibrary(library.uri, dependencies: dependencies);
    }

    final partial = File('${library.path}.part');
    try {
      directory.createSync(recursive: true);
      await _download(release.assetUri(asset), partial);
      final actualHash = await _sha256(partial);
      if (actualHash != expectedHash) {
        _log(
          'rust_http: $asset from ${release.tag} has SHA-256 $actualHash, '
          'expected $expectedHash. Ignoring it.',
        );
        return null;
      }
      partial.renameSync(library.path);
    } on Object catch (error) {
      _log('rust_http: could not download $asset from ${release.tag}: $error');
      return null;
    } finally {
      if (partial.existsSync()) partial.deleteSync();
    }
    return LocatedLibrary(library.uri, dependencies: dependencies);
  }

  static Future<String> _sha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  static Future<void> _httpDownload(Uri uri, File destination) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      await response
          .timeout(const Duration(seconds: 60))
          .pipe(destination.openWrite());
    } finally {
      client.close(force: true);
    }
  }
}

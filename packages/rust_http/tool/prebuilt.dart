// Release tooling for the prebuilt rust_http native libraries.
//
//   dart run tool/prebuilt.dart fingerprint
//     Prints `fingerprint=<hex>` and `tag=<release tag>` for the current Rust
//     sources, in GITHUB_OUTPUT format.
//
//   dart run tool/prebuilt.dart manifest <directory>
//     Writes manifest.json, with the SHA-256 of every library in
//     <directory>, next to them. The prebuilt workflow uploads it with the
//     libraries.
//
//   dart run tool/prebuilt.dart update
//     Reads manifest.json from the release matching the current sources and
//     writes lib/src/native_build/prebuilt_manifest.dart. Run it after the
//     prebuilt workflow has finished, then commit the result.
//
// Run every command from packages/rust_http.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:rust_http/src/native_build/native_source_fingerprint.dart';
import 'package:rust_http/src/native_build/prebuilt_release.dart';

const _manifestDart = 'lib/src/native_build/prebuilt_manifest.dart';

Future<void> main(List<String> arguments) async {
  final fingerprint = NativeSourceFingerprint.compute(
    Directory('native').absolute.uri,
  );
  final tag = PrebuiltRelease.tagFor(fingerprint);
  switch (arguments) {
    case ['fingerprint']:
      stdout
        ..writeln('fingerprint=$fingerprint')
        ..writeln('tag=$tag');
    case ['manifest', final directory]:
      await _writeManifest(Directory(directory), tag, fingerprint);
    case ['update']:
      await _update(tag, fingerprint);
    default:
      stderr.writeln(
        'usage: dart run tool/prebuilt.dart fingerprint|manifest <dir>|update',
      );
      exitCode = 64;
  }
}

Future<void> _writeManifest(
  Directory directory,
  String tag,
  String fingerprint,
) async {
  final assets = <String, String>{};
  final files =
      directory.listSync().whereType<File>().where(_isLibrary).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    assets[name] = (await sha256.bind(file.openRead()).first).toString();
  }
  if (assets.isEmpty) {
    stderr.writeln('No libraries in ${directory.path}.');
    exitCode = 1;
    return;
  }
  final manifest = {'tag': tag, 'fingerprint': fingerprint, 'assets': assets};
  File('${directory.path}/manifest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  stdout.writeln('Wrote manifest for ${assets.length} libraries ($tag).');
}

bool _isLibrary(File file) =>
    file.path.endsWith('.so') ||
    file.path.endsWith('.dylib') ||
    file.path.endsWith('.dll');

Future<void> _update(String tag, String fingerprint) async {
  final release = PrebuiltRelease(
    tag: tag,
    fingerprint: fingerprint,
    sha256ByAsset: const {},
  );
  final uri = release.assetUri('manifest.json');
  final client = HttpClient();
  final Map<String, Object?> manifest;
  try {
    final response = await (await client.getUrl(uri)).close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln(
        'No release $tag (HTTP ${response.statusCode} for $uri). Run the '
        'rust_http prebuilt workflow on a commit with these Rust sources '
        'first.',
      );
      exitCode = 1;
      return;
    }
    manifest = jsonDecode(body) as Map<String, Object?>;
  } finally {
    client.close(force: true);
  }

  if (manifest['fingerprint'] != fingerprint || manifest['tag'] != tag) {
    stderr.writeln('Release $tag was built from other Rust sources.');
    exitCode = 1;
    return;
  }
  final assets = (manifest['assets']! as Map<String, Object?>).map(
    (name, hash) => MapEntry(name, hash! as String),
  );
  final entries = [
    for (final name in assets.keys.toList()..sort())
      "      '$name': '${assets[name]}',",
  ].join('\n');
  File(_manifestDart).writeAsStringSync('''
// The prebuilt native libraries this version of rust_http downloads.
//
// Written by `dart run tool/prebuilt.dart update` after the rust_http
// prebuilt workflow has published a release. Do not edit by hand.

import 'prebuilt_release.dart';

/// The release whose libraries match this package's Rust sources, or null
/// when none has been published yet.
const PrebuiltRelease? prebuiltRelease = PrebuiltRelease(
  tag: '$tag',
  fingerprint: '$fingerprint',
  sha256ByAsset: {
$entries
  },
);
''');
  stdout.writeln('Updated $_manifestDart for $tag (${assets.length} assets).');
}

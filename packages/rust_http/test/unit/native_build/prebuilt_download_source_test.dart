import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:rust_http/src/native_build/native_build_context.dart';
import 'package:rust_http/src/native_build/native_source_fingerprint.dart';
import 'package:rust_http/src/native_build/prebuilt_download_source.dart';
import 'package:rust_http/src/native_build/prebuilt_release.dart';
import 'package:test/test.dart';

void main() {
  const asset = 'linux-x64-librust_http.so';
  final libraryBytes = 'native library'.codeUnits;
  final libraryHash = sha256.convert(libraryBytes).toString();

  late Directory root;
  late NativeBuildContext context;
  late PrebuiltRelease release;
  late List<Uri> downloads;
  late List<String> logs;

  void write(String relative, String content) => File('${root.path}/$relative')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  PrebuiltRelease releaseWith({String? fingerprint, String? hash}) {
    final current = NativeSourceFingerprint.compute(context.nativeRoot);
    return PrebuiltRelease(
      tag: PrebuiltRelease.tagFor(current),
      fingerprint: fingerprint ?? current,
      sha256ByAsset: {asset: hash ?? libraryHash},
    );
  }

  PrebuiltDownloadSource sourceFor(
    PrebuiltRelease? release, {
    List<int>? served,
  }) => PrebuiltDownloadSource(
    release: release,
    download: (uri, destination) async {
      downloads.add(uri);
      destination.writeAsBytesSync(served ?? libraryBytes);
    },
    log: logs.add,
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('rust_http_prebuilt_');
    write('native/Cargo.toml', '[package]\n');
    write('native/Cargo.lock', 'lock\n');
    write('native/src/lib.rs', 'fn main() {}\n');
    context = NativeBuildContext(
      packageRoot: root.uri,
      libraryFileName: 'librust_http.so',
      targetName: 'linux-x64',
      isHostTarget: true,
      sharedOutputDirectory: root.uri.resolve('out/'),
    );
    release = releaseWith();
    downloads = [];
    logs = [];
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('Given a release matching the sources', () {
    test('When located, Then it downloads and verifies the asset', () async {
      final found = await sourceFor(release).locate(context);

      expect(downloads.single, release.assetUri(asset));
      expect(File.fromUri(found!.file).readAsBytesSync(), libraryBytes);
      expect(
        found.dependencies.map((uri) => uri.pathSegments.last),
        containsAll(['Cargo.toml', 'Cargo.lock', 'lib.rs']),
      );
    });

    test('When located twice, Then the cached file is reused', () async {
      await sourceFor(release).locate(context);

      final found = await sourceFor(release).locate(context);

      expect(downloads, hasLength(1));
      expect(found, isNotNull);
    });

    test('When the download is corrupt, Then it is rejected', () async {
      final found = await sourceFor(
        release,
        served: 'tampered'.codeUnits,
      ).locate(context);

      expect(found, isNull);
      expect(logs.single, contains('expected $libraryHash'));
      expect(
        Directory.fromUri(root.uri.resolve('out/prebuilt/${release.tag}/'))
            .listSync(),
        isEmpty,
      );
    });

    test('When the download fails, Then it falls back', () async {
      final source = PrebuiltDownloadSource(
        release: release,
        download: (uri, _) => throw const SocketException('offline'),
        log: logs.add,
      );

      expect(await source.locate(context), isNull);
      expect(logs.single, contains('offline'));
    });

    test('When the target has no asset, Then it is skipped', () async {
      final found = await sourceFor(release)
          .locate(context.copyWith(targetName: 'linux-riscv64'));

      expect(found, isNull);
      expect(downloads, isEmpty);
    });

    test('When the app opts out, Then it is skipped', () async {
      final found = await sourceFor(release)
          .locate(context.copyWith(usePrebuilt: false));

      expect(found, isNull);
      expect(downloads, isEmpty);
    });
  });

  group('Given sources changed since the release', () {
    test('When located, Then it is skipped so cargo builds them', () async {
      final stale = releaseWith(fingerprint: 'other');

      expect(await sourceFor(stale).locate(context), isNull);
      expect(downloads, isEmpty);
    });
  });

  group('Given no published release', () {
    test('When located, Then it is skipped', () async {
      expect(await sourceFor(null).locate(context), isNull);
    });
  });

  group('NativeSourceFingerprint', () {
    test('ignores line endings', () {
      final before = NativeSourceFingerprint.compute(context.nativeRoot);

      write('native/src/lib.rs', 'fn main() {}\r\n');

      expect(NativeSourceFingerprint.compute(context.nativeRoot), before);
    });

    test('changes when a source changes', () {
      final before = NativeSourceFingerprint.compute(context.nativeRoot);

      write('native/src/extra.rs', 'pub fn f() {}\n');

      expect(
        NativeSourceFingerprint.compute(context.nativeRoot),
        isNot(before),
      );
    });

    test('ignores files outside the crate sources', () {
      final before = NativeSourceFingerprint.compute(context.nativeRoot);

      write('native/target/release/librust_http.so', 'binary');
      write('native/fuzz/src/main.rs', 'fn main() {}\n');

      expect(NativeSourceFingerprint.compute(context.nativeRoot), before);
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Identifies the Rust sources a native library is built from.
///
/// A prebuilt library is only used when its fingerprint matches the sources
/// in the package, so a library built from other sources is never loaded
/// against these FFI bindings.
abstract final class NativeSourceFingerprint {
  /// The SHA-256 fingerprint of the crate at [nativeRoot], in hex.
  ///
  /// It covers `Cargo.toml`, `Cargo.lock` and every `.rs` file under `src/`,
  /// keyed by their path relative to [nativeRoot]. Line endings are
  /// normalized, so a Windows checkout with CRLF files matches.
  static String compute(Uri nativeRoot) {
    final files = sourceFiles(nativeRoot);
    final rootPath = Directory.fromUri(nativeRoot).absolute.uri.path;
    final entries = [
      for (final file in files)
        (path: file.absolute.uri.path.substring(rootPath.length), file: file),
    ]..sort((a, b) => a.path.compareTo(b.path));

    final buffer = BytesBuilder(copy: false);
    for (final entry in entries) {
      final content = entry.file.readAsStringSync().replaceAll('\r\n', '\n');
      buffer
        ..add(utf8.encode(entry.path))
        ..addByte(0)
        ..add(utf8.encode(content))
        ..addByte(0);
    }
    return sha256.convert(buffer.takeBytes()).toString();
  }

  /// The files [compute] reads, for build dependency tracking.
  static List<File> sourceFiles(Uri nativeRoot) {
    final files = <File>[];
    for (final name in ['Cargo.toml', 'Cargo.lock']) {
      final file = File.fromUri(nativeRoot.resolve(name));
      if (file.existsSync()) files.add(file);
    }
    final src = Directory.fromUri(nativeRoot.resolve('src/'));
    if (src.existsSync()) {
      for (final entity in src.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.rs')) files.add(entity);
      }
    }
    return files;
  }
}

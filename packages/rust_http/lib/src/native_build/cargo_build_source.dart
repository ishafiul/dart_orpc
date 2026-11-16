import 'dart:io';

import 'native_build_context.dart';
import 'native_library_source.dart';
import 'native_source_fingerprint.dart';

/// Runs a process, like [Process.run].
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Builds the library from source with `cargo build --release`.
///
/// Every Rust source file is reported as a dependency, so a change to any of
/// them rebuilds the library.
final class CargoBuildSource implements NativeLibrarySource {
  /// Creates the source. [runProcess] and [log] are replaceable for tests.
  CargoBuildSource({ProcessRunner? runProcess, void Function(String)? log})
    : _runProcess = runProcess ?? Process.run,
      _log = log ?? stderr.writeln;

  final ProcessRunner _runProcess;
  final void Function(String) _log;

  @override
  Future<LocatedLibrary?> locate(NativeBuildContext context) async {
    if (!context.isHostTarget) return null;
    final native = context.nativeRoot;
    final targetDirectory = context.sharedOutputDirectory.resolve('cargo/');
    try {
      final result = await _runProcess(_cargoExecutable(), [
        'build',
        '--release',
        '--manifest-path',
        File.fromUri(native.resolve('Cargo.toml')).path,
        '--target-dir',
        Directory.fromUri(targetDirectory).path,
      ]);
      if (result.exitCode != 0) {
        _log('rust_http: cargo build failed\n${result.stderr}');
        return null;
      }
    } on ProcessException {
      return null;
    }
    final library = targetDirectory.resolve(
      'release/${context.libraryFileName}',
    );
    if (!File.fromUri(library).existsSync()) return null;
    return LocatedLibrary(
      library,
      dependencies: [
        for (final file in NativeSourceFingerprint.sourceFiles(native))
          file.absolute.uri,
      ],
    );
  }

  /// `cargo` from `~/.cargo/bin` when there, else from `PATH`.
  static String _cargoExecutable() {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      final binary = Platform.isWindows ? 'cargo.exe' : 'cargo';
      final file = File('$home/.cargo/bin/$binary');
      if (file.existsSync()) return file.path;
    }
    return 'cargo';
  }
}

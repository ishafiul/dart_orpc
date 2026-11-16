import 'dart:io';

const _minimumCoverage = '90';
const _runtimePackages = <String>[
  'dart_orpc_core',
  'dart_orpc_client',
  'dart_orpc_http',
  'dart_orpc_websocket',
  'dart_orpc_openapi',
];

Future<void> main() async {
  for (final package in _runtimePackages) {
    final packagePath = 'packages/$package';
    final coverageDirectory = Directory('coverage/$package');
    if (coverageDirectory.existsSync()) {
      coverageDirectory.deleteSync(recursive: true);
    }

    // Run tests from the package itself: from the workspace root, `dart test`
    // does not bundle the native libraries of packages such as rust_http.
    await _run([
      'test',
      '--coverage=${coverageDirectory.absolute.path}',
    ], workingDirectory: packagePath);
    await _run([
      'run',
      'coverage:format_coverage',
      '--packages=.dart_tool/package_config.json',
      '--report-on=$packagePath/lib',
      '--in=${coverageDirectory.path}',
      '--out=coverage/$package.lcov',
      '--lcov',
    ]);
    await _run([
      'run',
      'tool/check_coverage.dart',
      'coverage/$package.lcov',
      _minimumCoverage,
      package,
    ]);
  }
}

Future<void> _run(List<String> arguments, {String? workingDirectory}) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) {
    exit(result);
  }
}

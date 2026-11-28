// `dart compile aot-snapshot` runs no build hooks, so the snapshot has no
// code asset for the native library. These tests run such a snapshot with
// `dartaotruntime` and check that rust_http finds the library beside it or
// through RUST_HTTP_LIB.
@TestOn('mac-os || linux')
@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String snapshot;
  late String library;
  final dart = Platform.resolvedExecutable;
  final runtime = File(dart).parent.uri.resolve('dartaotruntime').toFilePath();

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('rust_http_aot_');
    final output = temp.uri.resolve('cli/').toFilePath();
    // `dart build cli` runs the build hook and puts the library in lib/.
    await _run(dart, [
      'build',
      'cli',
      '-t',
      'example/hello.dart',
      '-o',
      output,
    ]);
    final libDirectory = Directory.fromUri(temp.uri.resolve('cli/bundle/lib/'));
    library = libDirectory
        .listSync()
        .whereType<File>()
        .singleWhere((f) => f.uri.pathSegments.last.contains('librust_http.'))
        .path;
    snapshot = temp.uri.resolve('cli/bundle/bin/hello.aot').toFilePath();
    await _run(dart, [
      'compile',
      'aot-snapshot',
      'example/hello.dart',
      '-o',
      snapshot,
    ]);
  });

  tearDownAll(() => temp.delete(recursive: true));

  test('finds the library in ../lib beside the snapshot', () async {
    expect(await _serveOnce(runtime, snapshot), 'Hello World');
  });

  test('finds the library through RUST_HTTP_LIB', () async {
    final elsewhere = temp.uri.resolve('elsewhere/hello.aot').toFilePath();
    await File(elsewhere).parent.create();
    await File(snapshot).copy(elsewhere);

    expect(
      await _serveOnce(
        runtime,
        elsewhere,
        environment: {'RUST_HTTP_LIB': library},
      ),
      'Hello World',
    );
  });

  test('explains RUST_HTTP_LIB when no library is found', () async {
    final alone = temp.uri.resolve('alone/hello.aot').toFilePath();
    await File(alone).parent.create();
    await File(snapshot).copy(alone);

    final result = await Process.run(runtime, [alone, '0']);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('RUST_HTTP_LIB'));
  });
}

Future<void> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    fail(
      '$executable ${arguments.join(' ')} failed (${result.exitCode}):\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
}

/// Starts the hello example on a free port, fetches `/` and stops it.
Future<String> _serveOnce(
  String runtime,
  String snapshot, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(runtime, [
    snapshot,
    '0',
  ], environment: environment);
  final stderrText = StringBuffer();
  final stderrDone = process.stderr
      .transform(utf8.decoder)
      .forEach(stderrText.write);
  try {
    final banner = await process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => fail('no banner; stderr: $stderrText'),
        );
    expect(banner, startsWith('rust_http on '), reason: '$stderrText');
    final port = int.parse(banner.split(' ').last);
    final client = HttpClient();
    try {
      final request = await client.get('127.0.0.1', port, '/');
      final response = await request.close();
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  } finally {
    process.kill();
    await process.exitCode;
    await stderrDone;
  }
}

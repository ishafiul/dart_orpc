import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_cli/dart_orpc_cli.dart';
import 'package:test/test.dart';

void main() {
  group('DartOrpcCli', () {
    test(
      'serve does not start a process for a non-dart_orpc directory',
      () async {
        final sandbox = await Directory.systemTemp.createTemp(
          'dart_orpc_cli_invalid_serve_',
        );
        addTearDown(() async {
          if (await sandbox.exists()) {
            await sandbox.delete(recursive: true);
          }
        });

        await File.fromUri(sandbox.uri.resolve('pubspec.yaml')).writeAsString(
          '''
name: plain_dart_app
dependencies:
  http: ^1.0.0
''',
        );
        await Directory.fromUri(sandbox.uri.resolve('bin/')).create();
        await File.fromUri(
          sandbox.uri.resolve('bin/server.dart'),
        ).writeAsString('void main() {}');

        var processStarted = false;
        final cli = DartOrpcCli(
          currentDirectory: sandbox,
          stdoutSink: _createSink(),
          stderrSink: _createSink(),
          processStarter: (executable, arguments, {workingDirectory}) async {
            processStarted = true;
            throw StateError('process should not start');
          },
        );

        final exitCode = await cli.run(['serve']);
        expect(exitCode, 64);
        expect(processStarted, isFalse);
      },
    );

    test(
      'watch does not start a process for a non-dart_orpc directory',
      () async {
        final sandbox = await Directory.systemTemp.createTemp(
          'dart_orpc_cli_invalid_watch_',
        );
        addTearDown(() async {
          if (await sandbox.exists()) {
            await sandbox.delete(recursive: true);
          }
        });

        await File.fromUri(sandbox.uri.resolve('pubspec.yaml')).writeAsString(
          '''
name: plain_dart_app
dependencies:
  http: ^1.0.0
''',
        );
        await Directory.fromUri(sandbox.uri.resolve('bin/')).create();
        await File.fromUri(
          sandbox.uri.resolve('bin/server.dart'),
        ).writeAsString('void main() {}');

        var processStarted = false;
        final cli = DartOrpcCli(
          currentDirectory: sandbox,
          stdoutSink: _createSink(),
          stderrSink: _createSink(),
          processStarter: (executable, arguments, {workingDirectory}) async {
            processStarted = true;
            throw StateError('process should not start');
          },
        );

        final exitCode = await cli.run(['watch']);
        expect(exitCode, 64);
        expect(processStarted, isFalse);
      },
    );
  });
}

IOSink _createSink() {
  return IOSink(StreamController<List<int>>().sink, encoding: utf8);
}

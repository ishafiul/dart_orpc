import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_cli/dart_orpc_cli.dart';
import 'package:test/test.dart';

void main() {
  group('Given an empty destination with a valid Dart package name', () {
    late Directory sandbox;
    late int exitCode;

    setUp(() async {
      sandbox = await Directory.systemTemp.createTemp('dart_orpc_cli_create_');
    });

    tearDown(() async {
      if (await sandbox.exists()) {
        await sandbox.delete(recursive: true);
      }
    });

    group('When create runs without dependency resolution', () {
      setUp(() async {
        final cli = DartOrpcCli(
          currentDirectory: sandbox,
          stdoutSink: _createSink(),
          stderrSink: _createSink(),
          processStarter: _unexpectedProcessStarter,
        );

        exitCode = await cli.run(['create', 'hello_app', '--no-pub-get']);
      });

      test('Then the command succeeds', () {
        expect(exitCode, 0);
      });

      test('Then it writes the minimal project structure', () {
        final project = Directory.fromUri(sandbox.uri.resolve('hello_app/'));

        expect(
          _relativeFilePaths(project),
          containsAll(<String>[
            'README.md',
            'bin/server.dart',
            'lib/hello_app.dart',
            'lib/src/app.dart',
            'lib/src/hello/hello_controller.dart',
            'lib/src/hello/hello_module.dart',
            'pubspec.yaml',
          ]),
        );
      });

      test('Then the generated contract exposes RPC and REST hello routes', () {
        final controller = File.fromUri(
          sandbox.uri.resolve('hello_app/lib/src/hello/hello_controller.dart'),
        ).readAsStringSync();

        expect(controller, contains("@Controller('hello')"));
        expect(controller, contains("name: 'say'"));
        expect(controller, contains("RestMapping.get('/hello')"));
        expect(controller, contains("'Hello, World!'"));
      });
    });
  });

  group('Given a destination that is not empty', () {
    test('When create runs then existing files are preserved', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'dart_orpc_cli_create_existing_',
      );
      addTearDown(() => sandbox.delete(recursive: true));
      final project = Directory.fromUri(sandbox.uri.resolve('hello_app/'));
      await project.create();
      final existingFile = File.fromUri(project.uri.resolve('keep.txt'));
      await existingFile.writeAsString('keep me');
      final cli = DartOrpcCli(
        currentDirectory: sandbox,
        stdoutSink: _createSink(),
        stderrSink: _createSink(),
        processStarter: _unexpectedProcessStarter,
      );

      final exitCode = await cli.run(['create', 'hello_app', '--no-pub-get']);

      expect(exitCode, 73);
      expect(existingFile.readAsStringSync(), 'keep me');
      expect(
        File.fromUri(project.uri.resolve('pubspec.yaml')).existsSync(),
        isFalse,
      );
    });
  });

  group('Given an invalid Dart package name', () {
    test('When create runs then no project is written', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'dart_orpc_cli_create_invalid_',
      );
      addTearDown(() => sandbox.delete(recursive: true));
      final cli = DartOrpcCli(
        currentDirectory: sandbox,
        stdoutSink: _createSink(),
        stderrSink: _createSink(),
        processStarter: _unexpectedProcessStarter,
      );

      final exitCode = await cli.run(['create', 'Hello-App', '--no-pub-get']);

      expect(exitCode, 64);
      expect(
        Directory.fromUri(sandbox.uri.resolve('Hello-App/')).existsSync(),
        isFalse,
      );
    });
  });
}

IOSink _createSink() {
  return IOSink(StreamController<List<int>>().sink, encoding: utf8);
}

Future<Process> _unexpectedProcessStarter(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  throw StateError('process should not start');
}

List<String> _relativeFilePaths(Directory directory) {
  final directoryPrefix = directory.path.endsWith(Platform.pathSeparator)
      ? directory.path
      : '${directory.path}${Platform.pathSeparator}';
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .map(
        (file) => file.path
            .substring(directoryPrefix.length)
            .replaceAll(Platform.pathSeparator, '/'),
      )
      .toList();
}

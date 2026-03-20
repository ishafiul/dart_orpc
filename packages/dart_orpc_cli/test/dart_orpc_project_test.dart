import 'dart:io';

import 'package:dart_orpc_cli/dart_orpc_cli.dart';
import 'package:test/test.dart';

void main() {
  group('DartOrpcProject.validateForServe', () {
    test('rejects a package without a dart_orpc runtime dependency', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'dart_orpc_cli_invalid_project_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      await File.fromUri(sandbox.uri.resolve('pubspec.yaml')).writeAsString('''
name: sample_app
dependencies:
  http: ^1.0.0
''');
      await Directory.fromUri(sandbox.uri.resolve('bin/')).create();
      await File.fromUri(
        sandbox.uri.resolve('bin/server.dart'),
      ).writeAsString('void main() {}');

      final project = await DartOrpcProject.discover(
        currentDirectory: sandbox.parent,
        projectPath: sandbox.path,
        entrypoint: 'bin/server.dart',
      );

      final validationError = await project.validateForServe();
      expect(validationError, isNotNull);
      expect(validationError, contains('is not a valid dart_orpc app'));
    });

    test('accepts a project with a dart_orpc runtime dependency', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'dart_orpc_cli_valid_project_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      await File.fromUri(sandbox.uri.resolve('pubspec.yaml')).writeAsString('''
name: sample_app
dependencies:
  dart_orpc: ^0.1.0
''');
      await Directory.fromUri(sandbox.uri.resolve('bin/')).create();
      await File.fromUri(
        sandbox.uri.resolve('bin/server.dart'),
      ).writeAsString('void main() {}');

      final project = await DartOrpcProject.discover(
        currentDirectory: sandbox.parent,
        projectPath: sandbox.path,
        entrypoint: 'bin/server.dart',
      );

      expect(await project.validateForServe(), isNull);
    });
  });

  group('DartOrpcProject.validateForWatch', () {
    test('requires build_runner and dart_orpc_generator', () async {
      final sandbox = await Directory.systemTemp.createTemp(
        'dart_orpc_cli_watch_project_',
      );
      addTearDown(() async {
        if (await sandbox.exists()) {
          await sandbox.delete(recursive: true);
        }
      });

      await File.fromUri(sandbox.uri.resolve('pubspec.yaml')).writeAsString('''
name: sample_app
dependencies:
  dart_orpc: ^0.1.0
''');
      await Directory.fromUri(sandbox.uri.resolve('bin/')).create();
      await File.fromUri(
        sandbox.uri.resolve('bin/server.dart'),
      ).writeAsString('void main() {}');

      final project = await DartOrpcProject.discover(
        currentDirectory: sandbox.parent,
        projectPath: sandbox.path,
        entrypoint: 'bin/server.dart',
      );

      final validationError = await project.validateForWatch();
      expect(validationError, isNotNull);
      expect(validationError, contains('watch-ready'));
    });
  });
}

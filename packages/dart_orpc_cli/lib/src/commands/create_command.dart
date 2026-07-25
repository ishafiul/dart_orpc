import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import '../command.dart';
import '../process_runner.dart';
import '../project_template.dart';

final class CreateCommand implements DartOrpcCommand {
  CreateCommand({
    required Directory currentDirectory,
    required IOSink stdoutSink,
    required IOSink stderrSink,
    required ProcessStarter processStarter,
  }) : _currentDirectory = currentDirectory,
       _stdout = stdoutSink,
       _stderr = stderrSink,
       _processStarter = processStarter;

  final Directory _currentDirectory;
  final IOSink _stdout;
  final IOSink _stderr;
  final ProcessStarter _processStarter;

  @override
  String get name => 'create';

  @override
  String get description => 'Create a minimal hello-world dart_orpc app.';

  @override
  ArgParser buildParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for create.',
      )
      ..addFlag(
        'pub-get',
        defaultsTo: true,
        help: 'Resolve dependencies after creating the project.',
      );
  }

  @override
  Future<int> run(ArgResults results) async {
    if (results.rest.length != 1) {
      _stderr.writeln('Provide exactly one project directory.');
      _stderr.writeln('Usage: dart_orpc create <project_directory>');
      return 64;
    }

    final projectPath = results.rest.single;
    final projectDirectory = Directory(
      path.normalize(path.join(_currentDirectory.path, projectPath)),
    );
    final packageName = path.basename(projectDirectory.path);
    if (!_isValidPackageName(packageName)) {
      _stderr.writeln(
        'Invalid Dart package name "$packageName". '
        'Use lowercase letters, numbers, and underscores.',
      );
      return 64;
    }

    if (await projectDirectory.exists() &&
        !await projectDirectory.list().isEmpty) {
      _stderr.writeln(
        'Cannot create "$projectPath": the destination is not empty.',
      );
      return 73;
    }

    await projectDirectory.create(recursive: true);
    final template = ProjectTemplate(packageName: packageName);
    for (final entry in template.files.entries) {
      final file = File(path.join(projectDirectory.path, entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsString(entry.value);
    }

    _stdout.writeln('Created $packageName at ${projectDirectory.path}.');

    if (results['pub-get'] as bool) {
      final process = await _processStarter('dart', [
        'pub',
        'get',
      ], workingDirectory: projectDirectory.path);
      pipeProcessOutput(
        process,
        stdoutSink: _stdout,
        stderrSink: _stderr,
        label: 'pub',
      );
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        _stderr.writeln('Dependency resolution failed.');
        return exitCode;
      }
    }

    _stdout.writeln('');
    _stdout.writeln('Next steps:');
    _stdout.writeln('  cd $projectPath');
    if (!(results['pub-get'] as bool)) {
      _stdout.writeln('  dart pub get');
    }
    _stdout.writeln('  dart run build_runner build');
    _stdout.writeln('  dart run bin/server.dart');
    return 0;
  }

  bool _isValidPackageName(String name) {
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name);
  }
}

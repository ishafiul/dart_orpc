import 'dart:io';

import 'package:args/args.dart';

import '../app_watch_runner.dart';
import '../command.dart';
import '../dart_orpc_project.dart';
import '../process_runner.dart';

final class WatchCommand implements DartOrpcCommand {
  WatchCommand({
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
  String get name => 'watch';

  @override
  String get description =>
      'Rebuild generated code and restart the server on changes.';

  @override
  ArgParser buildParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for watch.',
      )
      ..addOption(
        'project',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Project directory to watch and run from.',
      )
      ..addOption(
        'entrypoint',
        abbr: 'e',
        defaultsTo: 'bin/server.dart',
        help: 'Entrypoint file, relative to the project directory.',
      );
  }

  @override
  Future<int> run(ArgResults results) async {
    final project = await DartOrpcProject.discover(
      currentDirectory: _currentDirectory,
      projectPath: _projectPathFromResults(results),
      entrypoint: results['entrypoint'] as String,
    );

    final validationError = await project.validateForWatch();
    if (validationError != null) {
      _stderr.writeln(validationError);
      return 64;
    }

    final runner = AppWatchRunner(
      project: project,
      stdoutSink: _stdout,
      stderrSink: _stderr,
      processStarter: _processStarter,
    );
    await runner.start();
    return 0;
  }

  String _projectPathFromResults(ArgResults results) {
    final optionValue = results['project'] as String;
    final positionalProject = results.rest.isNotEmpty
        ? results.rest.first
        : null;
    return positionalProject ?? optionValue;
  }
}

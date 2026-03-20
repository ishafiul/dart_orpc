import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import '../command.dart';
import '../dart_orpc_project.dart';
import '../process_runner.dart';

final class ServeCommand implements DartOrpcCommand {
  ServeCommand({
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
  String get name => 'serve';

  @override
  String get description => 'Run a dart_orpc server entrypoint once.';

  @override
  ArgParser buildParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information for serve.',
      )
      ..addOption(
        'project',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Project directory to run from.',
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

    final validationError = await project.validateForServe();
    if (validationError != null) {
      _stderr.writeln(validationError);
      return 64;
    }

    _stdout.writeln(
      '[serve] Running ${project.entrypointFile.path} from ${project.projectDirectory.path}.',
    );

    final process = await _processStarter('dart', [
      'run',
      project.entrypoint,
    ], workingDirectory: project.projectDirectory.path);
    pipeProcessOutput(
      process,
      stdoutSink: _stdout,
      stderrSink: _stderr,
      label: 'server',
    );

    final signalSubscriptions = <StreamSubscription<ProcessSignal>>[];
    Future<void> shutdown() async {
      for (final subscription in signalSubscriptions) {
        await subscription.cancel();
      }
      await stopProcess(process);
    }

    signalSubscriptions.add(
      ProcessSignal.sigint.watch().listen((_) {
        unawaited(shutdown());
      }),
    );

    if (!Platform.isWindows) {
      signalSubscriptions.add(
        ProcessSignal.sigterm.watch().listen((_) {
          unawaited(shutdown());
        }),
      );
    }

    final exitCode = await process.exitCode;
    for (final subscription in signalSubscriptions) {
      await subscription.cancel();
    }

    return exitCode;
  }

  String _projectPathFromResults(ArgResults results) {
    final optionValue = results['project'] as String;
    final positionalProject = results.rest.isNotEmpty
        ? results.rest.first
        : null;
    return positionalProject ?? optionValue;
  }
}

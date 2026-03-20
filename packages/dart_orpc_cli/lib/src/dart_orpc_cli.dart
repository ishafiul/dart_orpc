import 'dart:io';

import 'package:args/args.dart';

import 'command.dart';
import 'commands/serve_command.dart';
import 'commands/watch_command.dart';
import 'process_runner.dart';

final class DartOrpcCli {
  DartOrpcCli({
    Directory? currentDirectory,
    IOSink? stdoutSink,
    IOSink? stderrSink,
    ProcessStarter processStarter = defaultProcessStarter,
  }) : _stdout = stdoutSink ?? stdout,
       _stderr = stderrSink ?? stderr,
       _commands = [
         ServeCommand(
           currentDirectory: currentDirectory ?? Directory.current,
           stdoutSink: stdoutSink ?? stdout,
           stderrSink: stderrSink ?? stderr,
           processStarter: processStarter,
         ),
         WatchCommand(
           currentDirectory: currentDirectory ?? Directory.current,
           stdoutSink: stdoutSink ?? stdout,
           stderrSink: stderrSink ?? stderr,
           processStarter: processStarter,
         ),
       ];

  final IOSink _stdout;
  final IOSink _stderr;
  final List<DartOrpcCommand> _commands;

  Future<int> run(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show usage information.',
      );

    final commandParsers = <String, ArgParser>{};
    final commandMap = <String, DartOrpcCommand>{};
    for (final command in _commands) {
      final commandParser = command.buildParser();
      parser.addCommand(command.name, commandParser);
      commandParsers[command.name] = commandParser;
      commandMap[command.name] = command;
    }

    late ArgResults results;
    try {
      results = parser.parse(arguments);
    } on ArgParserException catch (error) {
      _stderr.writeln(error.message);
      _stderr.writeln('');
      _stderr.writeln(_rootUsage(parser));
      return 64;
    }

    if (results['help'] as bool) {
      _stdout.writeln(_rootUsage(parser));
      return 0;
    }

    final selectedCommand = results.command;
    if (selectedCommand == null) {
      _stderr.writeln('A command is required.');
      _stderr.writeln('');
      _stderr.writeln(_rootUsage(parser));
      return 64;
    }

    final command = commandMap[selectedCommand.name];
    final commandParser = commandParsers[selectedCommand.name];
    if (command == null || commandParser == null) {
      _stderr.writeln('Unknown command "${selectedCommand.name}".');
      _stderr.writeln('');
      _stderr.writeln(_rootUsage(parser));
      return 64;
    }

    if (selectedCommand['help'] as bool) {
      _stdout.writeln(_commandUsage(command.name, commandParser));
      return 0;
    }

    return command.run(selectedCommand);
  }

  String _rootUsage(ArgParser parser) {
    final lines = <String>[
      'Usage: dart_orpc <command> [options]',
      '',
      'Available commands:',
    ];
    for (final command in _commands) {
      lines.add('  ${command.name.padRight(8)}${command.description}');
    }
    lines.add('');
    lines.add('Global options:');
    lines.add(parser.usage);
    return lines.join('\n');
  }

  String _commandUsage(String commandName, ArgParser parser) {
    return [
      'Usage: dart_orpc $commandName [options]',
      '',
      parser.usage,
    ].join('\n');
  }
}

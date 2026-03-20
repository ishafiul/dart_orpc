import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

Future<Process> defaultProcessStarter(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
}

void pipeProcessOutput(
  Process process, {
  required IOSink stdoutSink,
  required IOSink stderrSink,
  required String label,
}) {
  process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => stdoutSink.writeln('[$label] $line'));

  process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) => stderrSink.writeln('[$label] $line'));
}

Future<void> stopProcess(Process process) async {
  final signal = Platform.isWindows
      ? ProcessSignal.sigkill
      : ProcessSignal.sigterm;
  if (process.kill(signal)) {
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
      return;
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }

  await process.exitCode;
}

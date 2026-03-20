import 'dart:async';
import 'dart:io';

import 'dart_orpc_project.dart';
import 'path_utils.dart';
import 'process_runner.dart';
import 'watch_plan.dart';

final class AppWatchRunner {
  AppWatchRunner({
    required DartOrpcProject project,
    required IOSink stdoutSink,
    required IOSink stderrSink,
    required ProcessStarter processStarter,
  }) : _project = project,
       _stdout = stdoutSink,
       _stderr = stderrSink,
       _processStarter = processStarter;

  final DartOrpcProject _project;
  final IOSink _stdout;
  final IOSink _stderr;
  final ProcessStarter _processStarter;

  final List<StreamSubscription<FileSystemEvent>> _fileWatchSubscriptions = [];
  Timer? _debounceTimer;

  Process? _buildProcess;
  Process? _serverProcess;

  bool _isClosing = false;
  bool _isCycleRunning = false;
  bool _rerunRequested = false;
  bool _pubGetRequested = false;
  String _pendingReason = 'workspace change';

  Future<void> start() async {
    final plan = await WatchPlan.discover(project: _project);

    _log('Starting watch mode.');

    for (final directory in plan.directoriesToWatch) {
      await _watchDirectory(directory);
    }

    for (final file in plan.filesToWatch) {
      await _watchFile(file);
    }

    _log('Watching ${plan.describeWatchedRoots()}. Press Ctrl+C to stop.');

    final signalSubscriptions = <StreamSubscription<ProcessSignal>>[];
    final done = Completer<void>();

    Future<void> shutdown() async {
      if (done.isCompleted) {
        return;
      }

      for (final subscription in signalSubscriptions) {
        await subscription.cancel();
      }

      await close();
      done.complete();
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

    await _runCycle(plan, 'initial startup');
    await done.future;
  }

  Future<void> close() async {
    if (_isClosing) {
      return;
    }

    _isClosing = true;
    _debounceTimer?.cancel();

    for (final subscription in _fileWatchSubscriptions) {
      await subscription.cancel();
    }

    final buildProcess = _buildProcess;
    if (buildProcess != null) {
      await stopProcess(buildProcess);
      _buildProcess = null;
    }

    final serverProcess = _serverProcess;
    if (serverProcess != null) {
      await stopProcess(serverProcess);
      _serverProcess = null;
    }

    _log('Watch mode stopped.');
  }

  Future<void> _watchDirectory(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }

    final subscription = directory
        .watch(recursive: true)
        .listen(_onFileSystemEvent);
    _fileWatchSubscriptions.add(subscription);
  }

  Future<void> _watchFile(File file) async {
    if (!await file.exists()) {
      return;
    }

    final subscription = file.watch().listen(_onFileSystemEvent);
    _fileWatchSubscriptions.add(subscription);
  }

  void _onFileSystemEvent(FileSystemEvent event) {
    if (_isClosing) {
      return;
    }

    final planFuture = WatchPlan.discover(project: _project);
    unawaited(
      planFuture.then((plan) {
        final normalizedPath = normalizePath(event.path);
        if (!plan.isRelevantPath(normalizedPath)) {
          return;
        }

        if (plan.requiresPubGet(normalizedPath)) {
          _pubGetRequested = true;
        }

        _pendingReason = plan.describeEvent(event.type, normalizedPath);
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          unawaited(_requestCycle(plan));
        });
      }),
    );
  }

  Future<void> _requestCycle(WatchPlan plan) async {
    if (_isClosing) {
      return;
    }

    if (_isCycleRunning) {
      _rerunRequested = true;
      return;
    }

    await _runCycle(plan, _pendingReason);
  }

  Future<void> _runCycle(WatchPlan plan, String reason) async {
    _isCycleRunning = true;

    try {
      _log('Change detected: $reason');

      if (_pubGetRequested) {
        final resolvedDependencies = await _runPubGet(plan);
        if (!resolvedDependencies || _isClosing) {
          return;
        }
      }

      final buildSucceeded = await _runBuild();
      if (!buildSucceeded || _isClosing) {
        return;
      }

      await _restartServer();
    } finally {
      _isCycleRunning = false;

      if (_rerunRequested && !_isClosing) {
        _rerunRequested = false;
        final refreshedPlan = await WatchPlan.discover(project: _project);
        await _runCycle(refreshedPlan, _pendingReason);
      }
    }
  }

  Future<bool> _runPubGet(WatchPlan plan) async {
    _pubGetRequested = false;
    _log('Running `dart pub get`.');

    final process = await _processStarter(
      'dart',
      ['pub', 'get'],
      workingDirectory:
          plan.workspaceRoot?.path ?? _project.projectDirectory.path,
    );
    pipeProcessOutput(
      process,
      stdoutSink: _stdout,
      stderrSink: _stderr,
      label: 'pub',
    );
    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      _log('`dart pub get` failed with exit code $exitCode.');
      return false;
    }

    return true;
  }

  Future<bool> _runBuild() async {
    _log('Running build_runner.');

    final process = await _processStarter('dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ], workingDirectory: _project.projectDirectory.path);
    _buildProcess = process;
    pipeProcessOutput(
      process,
      stdoutSink: _stdout,
      stderrSink: _stderr,
      label: 'build',
    );

    final exitCode = await process.exitCode;
    _buildProcess = null;

    if (exitCode != 0) {
      _log('build_runner failed with exit code $exitCode.');
      return false;
    }

    return true;
  }

  Future<void> _restartServer() async {
    final existingServer = _serverProcess;
    if (existingServer != null) {
      await stopProcess(existingServer);
      _serverProcess = null;
    }

    _log('Starting ${_project.entrypoint}.');
    final process = await _processStarter('dart', [
      'run',
      _project.entrypoint,
    ], workingDirectory: _project.projectDirectory.path);
    _serverProcess = process;
    pipeProcessOutput(
      process,
      stdoutSink: _stdout,
      stderrSink: _stderr,
      label: 'server',
    );

    unawaited(
      process.exitCode.then((exitCode) {
        if (_serverProcess == process) {
          _serverProcess = null;
          if (!_isClosing) {
            _log('Server exited with code $exitCode.');
          }
        }
      }),
    );
  }

  void _log(String message) {
    _stdout.writeln('[watch] $message');
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'rpc_http_app.dart';

/// Boots independent apps; limits, metrics, and DI singletons are worker-local.
/// Factories must be sendable: prefer top-level functions without captured resources.
final class RpcHttpIsolateServer {
  RpcHttpIsolateServer._();

  final List<_HttpWorker> _workers = [];
  final Completer<void> _done = Completer<void>();
  Future<void>? _closing;
  Object? _failure;
  StackTrace? _failureStack;
  bool _started = false;
  late final int port;
  late final InternetAddress address;

  int get workerCount => _workers.length;

  /// Completes on shutdown; reports unexpected worker exits and cleanup failures.
  Future<void> get done => _done.future;

  static Future<RpcHttpIsolateServer> start({
    required FutureOr<RpcHttpApp> Function() createApp,
    required int port,
    required int workers,
    String hostname = '0.0.0.0',
    Duration startupTimeout = const Duration(seconds: 30),
    FutureOr<void> Function(RpcHttpApp app)? disposeApp,
  }) async {
    if (workers <= 0) throw ArgumentError.value(workers, 'workers');
    if (port < 0 || port > 65535) throw ArgumentError.value(port, 'port');
    if (startupTimeout <= Duration.zero) {
      throw ArgumentError.value(startupTimeout, 'startupTimeout');
    }
    final server = RpcHttpIsolateServer._();
    // Keep failure observable through done without an unhandled async error when
    // callers only await close or a startup failure.
    unawaited(
      server.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    try {
      for (var index = 0; index < workers; index++) {
        final worker = await _HttpWorker.spawn(
          _WorkerStart(
            createApp,
            disposeApp,
            index == 0 ? hostname : server.address.address,
            index == 0 ? port : server.port,
          ),
          index,
          server._workerFailed,
        );
        server._workers.add(worker);
        final ready = await worker.ready.timeout(startupTimeout);
        if (index == 0) {
          server.port = ready.port;
          server.address = InternetAddress(ready.address);
        }
        final failure = server._failure;
        if (failure != null)
          Error.throwWithStackTrace(
            failure,
            server._failureStack ?? StackTrace.current,
          );
      }
      server._started = true;
      return server;
    } catch (error, stack) {
      server._recordFailure(error, stack);
      await server.close(force: true).catchError((Object _) {});
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> close({
    Duration gracePeriod = const Duration(seconds: 30),
    bool force = false,
  }) {
    if (gracePeriod < Duration.zero)
      throw ArgumentError.value(gracePeriod, 'gracePeriod');
    return _closing ??= _close(gracePeriod: gracePeriod, force: force);
  }

  void _recordFailure(Object error, StackTrace stack) {
    _failure ??= error;
    _failureStack ??= stack;
  }

  void _workerFailed(Object error, StackTrace stack) {
    _recordFailure(error, stack);
    if (_started && _closing == null) {
      unawaited(close(force: true).catchError((Object _) {}));
    }
  }

  Future<void> _close({
    required Duration gracePeriod,
    required bool force,
  }) async {
    try {
      await Future.wait([
        for (final worker in _workers)
          worker.stop(gracePeriod: gracePeriod, force: force),
      ]);
    } catch (error, stack) {
      _recordFailure(error, stack);
    }
    final failure = _failure;
    if (failure != null) {
      final stack = _failureStack ?? StackTrace.current;
      _done.completeError(failure, stack);
      Error.throwWithStackTrace(failure, stack);
    }
    _done.complete();
  }
}

final class _HttpWorker {
  _HttpWorker(this._onFailure) {
    _subscription = _events.listen(_receive);
    unawaited(ready.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  }

  final void Function(Object, StackTrace) _onFailure;
  final ReceivePort _events = ReceivePort();
  final Completer<_WorkerReady> _ready = Completer<_WorkerReady>();
  final Completer<void> _exited = Completer<void>();
  late final StreamSubscription<Object?> _subscription;
  late final Isolate _isolate;
  SendPort? _commands;
  bool _stopping = false;
  bool _stopped = false;
  bool _failed = false;

  Future<_WorkerReady> get ready => _ready.future;

  static Future<_HttpWorker> spawn(
    _WorkerStart configuration,
    int index,
    void Function(Object, StackTrace) onFailure,
  ) async {
    final worker = _HttpWorker(onFailure);
    try {
      worker._isolate = await Isolate.spawn(
        _serveWorker,
        (configuration, worker._events.sendPort),
        debugName: 'dart-orpc-http-$index',
        onError: worker._events.sendPort,
        onExit: worker._events.sendPort,
      );
      return worker;
    } catch (_) {
      await worker._subscription.cancel();
      worker._events.close();
      rethrow;
    }
  }

  void _fail(String message, String stack) {
    if (_failed) return;
    _failed = true;
    final error = RemoteError(message, stack);
    final trace = StackTrace.fromString(stack);
    if (!_ready.isCompleted) _ready.completeError(error, trace);
    _onFailure(error, trace);
  }

  void _receive(Object? event) {
    switch (event) {
      case _WorkerReady():
        _commands = event.commands;
        _ready.complete(event);
      case _WorkerStopped():
        _stopped = true;
      case _WorkerFailure():
        _fail(event.message, event.stack);
      case [final String message, final String stack]:
        _fail(message, stack);
      case null:
        if (!_stopping || !_stopped) {
          _fail('HTTP worker exited unexpectedly.', '');
        }
        _exited.complete();
    }
  }

  Future<void> stop({
    required Duration gracePeriod,
    required bool force,
  }) async {
    _stopping = true;
    if (!_exited.isCompleted) {
      final commands = _commands;
      if (commands == null) {
        _stopped = true;
        _isolate.kill(priority: Isolate.immediate);
      } else {
        commands.send(_StopWorker(gracePeriod, force));
      }
      // A blocked worker cannot receive shutdown commands. Bound shutdown even
      // when application cleanup hangs. Hard termination bypasses cleanup;
      // report failure so the caller can restart the process if needed.
      await _exited.future.timeout(
        (force ? Duration.zero : gracePeriod) + const Duration(seconds: 1),
        onTimeout: () {
          _onFailure(
            TimeoutException('HTTP worker did not finish shutdown.'),
            StackTrace.current,
          );
          _stopped = true;
          _isolate.kill(priority: Isolate.immediate);
        },
      );
      await _exited.future;
    }
    await _subscription.cancel();
    _events.close();
  }
}

final class _WorkerStart {
  const _WorkerStart(this.createApp, this.disposeApp, this.hostname, this.port);
  final FutureOr<RpcHttpApp> Function() createApp;
  final FutureOr<void> Function(RpcHttpApp)? disposeApp;
  final String hostname;
  final int port;
}

final class _WorkerReady {
  const _WorkerReady(this.commands, this.port, this.address);
  final SendPort commands;
  final int port;
  final String address;
}

final class _StopWorker {
  const _StopWorker(this.gracePeriod, this.force);
  final Duration gracePeriod;
  final bool force;
}

final class _WorkerFailure {
  const _WorkerFailure(this.message, this.stack);
  final String message;
  final String stack;
}

final class _WorkerStopped {
  const _WorkerStopped();
}

Future<void> _serveWorker((_WorkerStart, SendPort) arguments) async {
  final fatal = Completer<_WorkerFailure>();
  await runZonedGuarded(() => _runWorker(arguments, fatal.future), (
    Object error,
    StackTrace stack,
  ) {
    if (!fatal.isCompleted) {
      fatal.complete(_WorkerFailure(error.toString(), stack.toString()));
    }
  });
  Isolate.exit();
}

Future<void> _runWorker(
  (_WorkerStart, SendPort) arguments,
  Future<_WorkerFailure> fatal,
) async {
  final (configuration, events) = arguments;
  final commands = ReceivePort();
  final stop = Completer<_StopWorker>();
  final commandSubscription = commands.listen((Object? command) {
    if (command is _StopWorker && !stop.isCompleted) stop.complete(command);
  });
  RpcHttpApp? app;
  RpcHttpServer? server;
  try {
    app = await Future.any<RpcHttpApp>([
      Future.sync(configuration.createApp),
      fatal.then(
        (failure) => throw RemoteError(failure.message, failure.stack),
      ),
    ]);
    server = await app.listen(
      configuration.port,
      hostname: configuration.hostname,
      shared: true,
    );
    events.send(
      _WorkerReady(commands.sendPort, server.port, server.address.address),
    );
    final command = await Future.any<Object?>([stop.future, fatal]);
    switch (command) {
      case _StopWorker():
        await server.close(
          gracePeriod: command.gracePeriod,
          force: command.force,
        );
      case _WorkerFailure():
        events.send(command);
        await server.close(force: true);
    }
  } catch (error, stack) {
    events.send(_WorkerFailure(error.toString(), stack.toString()));
  } finally {
    try {
      await server?.close(force: true);
    } catch (error, stack) {
      events.send(_WorkerFailure(error.toString(), stack.toString()));
    }
    try {
      if (app != null) await configuration.disposeApp?.call(app);
    } catch (error, stack) {
      events.send(_WorkerFailure(error.toString(), stack.toString()));
    }
    await commandSubscription.cancel();
    commands.close();
  }
  events.send(const _WorkerStopped());
}

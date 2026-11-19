import 'dart:async';
import 'dart:collection';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';

import 'console_exporter.dart';
import 'export_worker.dart';
import 'telemetry_model.dart';
import 'trace_context.dart';

const _ambientLoggerZoneKey = #dart_orpc_logger.ambient;
const _accessScope = 'dart_orpc.access';
const _serverScope = 'dart_orpc.server';
const _serverStarted = 'server.started';
const _serverStopped = 'server.stopped';
const _errorScope = 'dart_orpc.error';
const _rpcSystem = 'dart_orpc';

/// Logs and traces every call of a dart_orpc app, and is the target of every
/// [Logger] that runs inside one.
///
/// Pass it to the generated `buildRpcApp(observer: ...)`. Each HTTP exchange
/// and WebSocket call then gets a server span and an access log record, and a
/// [Logger] used anywhere in that call (a guard, a service) is tagged with the
/// call's trace and span ids automatically.
///
/// Recording a record only appends it to a bounded in-memory queue. Exporters
/// run in the background in batches, so a slow or failing exporter never
/// delays a response. When the queue is full, the oldest records are dropped
/// and counted in [droppedRecords].
final class RpcLogger implements RpcObserver {
  RpcLogger({
    List<RpcTelemetryExporter>? exporters,
    this.minSeverity = RpcLogSeverity.info,
    this.resource = const RpcTelemetryResource(serviceName: _rpcSystem),
    this.accessLog = true,
    this.traces = true,
    this.traceSampleRatio = 1.0,
    this.maxQueuedRecords = 2048,
    this.maxBatchSize = 512,
    this.flushInterval = const Duration(seconds: 1),
    this.exportTimeout = const Duration(seconds: 10),
    this.onExportError,
    this.backgroundExport = true,
    RpcTraceIds? ids,
  }) : exporters = List.unmodifiable(
         exporters ?? [RpcConsoleExporter.pretty()],
       ),
       _ids = ids ?? RpcTraceIds() {
    if (maxQueuedRecords < 1 || maxBatchSize < 1) {
      throw ArgumentError('Queue and batch sizes must be positive.');
    }
    if (traceSampleRatio < 0 || traceSampleRatio > 1) {
      throw ArgumentError.value(
        traceSampleRatio,
        'traceSampleRatio',
        'must be between 0 and 1',
      );
    }
  }

  /// The logger [Logger]s use outside any call and outside [run]: pretty
  /// console output at [RpcLogSeverity.info].
  static final RpcLogger fallback = RpcLogger();

  final List<RpcTelemetryExporter> exporters;
  final RpcLogSeverity minSeverity;
  final RpcTelemetryResource resource;

  /// Whether every call produces an access log record.
  final bool accessLog;

  /// Whether every sampled call produces a server span.
  final bool traces;

  /// The share of calls without an incoming sampling decision that are traced.
  final double traceSampleRatio;
  final int maxQueuedRecords;
  final int maxBatchSize;
  final Duration flushInterval;
  final Duration exportTimeout;
  final void Function(Object error, StackTrace stackTrace)? onExportError;

  /// Whether exporters run in a background isolate, so formatting and I/O
  /// never take CPU time from serving requests. Exporters that cannot move
  /// to another isolate, such as one given an open `IOSink`, run in this
  /// isolate instead.
  final bool backgroundExport;
  final RpcTraceIds _ids;
  Future<ExportWorker?>? _worker;

  final ListQueue<RpcLogRecord> _logs = ListQueue();
  final ListQueue<RpcSpanRecord> _spans = ListQueue();
  Timer? _flushTimer;
  Future<void>? _flushing;
  Future<void>? _closing;
  var _droppedRecords = 0;
  var _exportFailures = 0;

  /// Records dropped because the queue was full or the logger was closed.
  int get droppedRecords => _droppedRecords;

  /// Exporter calls that failed or timed out.
  int get exportFailures => _exportFailures;

  /// A [Logger] that always writes here, even outside a call.
  Logger logger(String scope) => Logger._bound(scope, this);

  bool isEnabled(RpcLogSeverity severity) => severity.isAtLeast(minSeverity);

  /// Runs [body] so that every [Logger] inside it writes here, for code that
  /// runs outside a call, such as startup in `main`.
  R run<R>(R Function() body) =>
      runZoned(body, zoneValues: {_ambientLoggerZoneKey: this});

  @override
  RpcCallObservation startCall(RpcObservedCallStart start) {
    final parent = RpcTraceContext.fromTraceparent(
      start.header(RpcTraceContext.headerName),
    );
    final sampled =
        traces && (parent?.sampled ?? _ids.sample(traceSampleRatio));
    return _CallObservation(
      logger: this,
      start: start,
      startedAt: DateTime.now(),
      trace: RpcTraceContext(
        traceId: parent?.traceId ?? _ids.traceId(),
        spanId: _ids.spanId(),
        sampled: sampled,
      ),
      parentSpanId: parent?.spanId,
    );
  }

  @override
  void serverStarted(RpcObservedServer server) =>
      _emitServerEvent(_serverStarted, server);

  @override
  void serverStopped(RpcObservedServer server) =>
      _emitServerEvent(_serverStopped, server);

  void _emitServerEvent(String event, RpcObservedServer server) => emit(
    RpcLogRecord(
      timestamp: DateTime.now(),
      severity: RpcLogSeverity.info,
      message: event,
      scope: _serverScope,
      attributes: {
        'service.name': resource.serviceName,
        'server.address': server.host,
        'server.port': server.port,
        for (final endpoint in server.endpoints)
          'url.${endpoint.name}': endpoint.url.toString(),
      },
    ),
  );

  void emit(RpcLogRecord record) {
    if (!isEnabled(record.severity)) {
      return;
    }
    _enqueue(_logs, record);
  }

  void _emitSpan(RpcSpanRecord span) => _enqueue(_spans, span);

  void _enqueue<T>(ListQueue<T> queue, T record) {
    if (_closing != null) {
      _droppedRecords++;
      return;
    }
    if (_logs.length + _spans.length >= maxQueuedRecords) {
      final oldest = _logs.isNotEmpty ? _logs : _spans;
      oldest.removeFirst();
      _droppedRecords++;
    }
    queue.add(record);
    if (_logs.length + _spans.length >= maxBatchSize) {
      _flushTimer?.cancel();
      _flushTimer = null;
      scheduleMicrotask(_flushInBackground);
    } else {
      _flushTimer ??= Timer(flushInterval, _flushInBackground);
    }
  }

  void _flushInBackground() {
    _flushTimer = null;
    unawaited(flush());
  }

  /// Exports everything queued so far.
  Future<void> flush() =>
      _flushing ??= _drain().whenComplete(() => _flushing = null);

  Future<void> _drain() async {
    final worker = await _startedWorker();
    while (_logs.isNotEmpty || _spans.isNotEmpty) {
      final batch = RpcTelemetryBatch(
        resource: resource,
        logs: _take(_logs),
        spans: _take(_spans),
      );
      if (worker == null) {
        await Future.wait([
          for (final exporter in exporters) _exportTo(exporter, batch),
        ]);
      } else {
        _reportWorkerFailures(await worker.export(batch));
      }
    }
  }

  Future<ExportWorker?> _startedWorker() {
    if (!backgroundExport || exporters.isEmpty) {
      return Future.value();
    }
    return _worker ??= ExportWorker.spawn(
      exporters,
      exportTimeout: exportTimeout,
    );
  }

  void _reportWorkerFailures(List<(String, String)> failures) {
    for (final (message, stackTrace) in failures) {
      _exportFailures++;
      onExportError?.call(
        RpcExportFailure(message),
        StackTrace.fromString(stackTrace),
      );
    }
  }

  List<T> _take<T>(ListQueue<T> queue) {
    final count = queue.length < maxBatchSize ? queue.length : maxBatchSize;
    return [for (var index = 0; index < count; index++) queue.removeFirst()];
  }

  Future<void> _exportTo(
    RpcTelemetryExporter exporter,
    RpcTelemetryBatch batch,
  ) async {
    try {
      await exporter.export(batch).timeout(exportTimeout);
    } on Object catch (error, stackTrace) {
      _exportFailures++;
      onExportError?.call(error, stackTrace);
    }
  }

  /// Exports what is queued, then shuts the exporters down. Records emitted
  /// afterwards are dropped.
  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flushing;
    await _drain();
    final worker = await _worker;
    if (worker != null) {
      _reportWorkerFailures(await worker.shutdown());
      return;
    }
    for (final exporter in exporters) {
      try {
        await exporter.shutdown().timeout(exportTimeout);
      } on Object catch (error, stackTrace) {
        _exportFailures++;
        onExportError?.call(error, stackTrace);
      }
    }
  }
}

final class _CallObservation implements RpcCallObservation {
  _CallObservation({
    required this.logger,
    required this.start,
    required this.startedAt,
    required this.trace,
    required this.parentSpanId,
  }) : rpcMethod = start.rpcMethod;

  final RpcLogger logger;
  final RpcObservedCallStart start;
  final DateTime startedAt;
  final RpcTraceContext trace;
  final String? parentSpanId;
  String? rpcMethod;
  Object? _error;
  StackTrace? _errorStackTrace;
  var _ended = false;

  @override
  void identify(String rpcMethod) => this.rpcMethod = rpcMethod;

  @override
  void recordError(Object error, StackTrace stackTrace) {
    _error ??= error;
    _errorStackTrace ??= stackTrace;
    if (_isClientError(error)) {
      return;
    }
    logger.emit(
      RpcLogRecord(
        timestamp: DateTime.now(),
        severity: RpcLogSeverity.error,
        message: _errorMessage(error),
        scope: _errorScope,
        attributes: {..._callAttributes(), ..._exceptionAttributes(error)},
        traceId: trace.traceId,
        spanId: trace.spanId,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void end(RpcObservedCallEnd end) {
    if (_ended) {
      return;
    }
    _ended = true;
    final finishedAt = startedAt.add(end.elapsed);
    final attributes = _callAttributes()..addAll(_endAttributes(end));
    final failed = _isServerFailure(end);
    if (logger.accessLog) {
      logger.emit(
        RpcLogRecord(
          timestamp: finishedAt,
          severity: failed
              ? RpcLogSeverity.error
              : (end.statusCode ?? 0) >= 400 || end.failed
              ? RpcLogSeverity.warn
              : RpcLogSeverity.info,
          message: _accessMessage(end),
          scope: _accessScope,
          attributes: attributes,
          traceId: trace.traceId,
          spanId: trace.spanId,
        ),
      );
    }
    if (trace.sampled) {
      final error = _error;
      logger._emitSpan(
        RpcSpanRecord(
          traceId: trace.traceId,
          spanId: trace.spanId,
          parentSpanId: parentSpanId,
          name: _spanName(end),
          start: startedAt,
          end: finishedAt,
          status: failed ? RpcSpanStatus.error : RpcSpanStatus.unset,
          statusMessage: failed && error != null ? _errorMessage(error) : null,
          attributes: attributes,
          events: [
            if (error != null)
              RpcSpanEvent(
                timestamp: finishedAt,
                name: 'exception',
                attributes: {
                  ..._exceptionAttributes(error),
                  'exception.stacktrace': ?_errorStackTrace?.toString(),
                },
              ),
          ],
        ),
      );
    }
  }

  bool _isServerFailure(RpcObservedCallEnd end) {
    final status = end.statusCode;
    if (status != null) {
      return status >= 500;
    }
    final error = _error;
    return end.failed && (error == null || !_isClientError(error));
  }

  String _spanName(RpcObservedCallEnd end) =>
      rpcMethod ?? '${start.method} ${end.route ?? start.path}';

  String _accessMessage(RpcObservedCallEnd end) {
    final target = switch (start.transport) {
      RpcTransportKind.http => '${start.method} ${start.path}',
      RpcTransportKind.webSocket => 'WS ${start.path}',
    };
    final outcome =
        end.statusCode?.toString() ??
        (end.failed
            ? 'failed'
            : end.disconnected
            ? 'cancelled'
            : 'ok');
    final millis = (end.elapsed.inMicroseconds / 1000).toStringAsFixed(1);
    return [target, ?rpcMethod, outcome, '${millis}ms'].join(' ');
  }

  RpcAttributes _callAttributes() => {
    'rpc.system': _rpcSystem,
    'rpc.method': ?rpcMethod,
    'network.transport': switch (start.transport) {
      RpcTransportKind.http => 'http',
      RpcTransportKind.webSocket => 'websocket',
    },
    'http.request.method': start.method,
    'url.path': start.path,
    'http.request.id': ?start.requestId,
    'rpc.call.id': ?start.callId,
    'client.address': ?start.remoteAddress,
  };

  RpcAttributes _endAttributes(RpcObservedCallEnd end) => {
    'http.server.request.duration': end.elapsed.inMicroseconds / 1e6,
    'http.route': ?end.route,
    'http.response.status_code': ?end.statusCode,
    'http.request.body.size': end.receivedBytes,
    'http.response.body.size': end.sentBytes,
    'rpc.streaming': end.streaming,
    if (end.disconnected) 'rpc.disconnected': true,
    'error.type': ?_errorType(),
  };

  String? _errorType() {
    final error = _error;
    return switch (error) {
      null => null,
      RpcException(:final code) => code.wireName,
      _ => error.runtimeType.toString(),
    };
  }
}

bool _isClientError(Object error) =>
    error is RpcException && error.statusCode < 500 && error.diagnostic == null;

String _errorMessage(Object error) => switch (error) {
  RpcException(:final message) => message,
  _ => error.toString(),
};

RpcAttributes _exceptionAttributes(Object error) => {
  'exception.type': switch (error) {
    RpcException(:final code) => code.wireName,
    _ => error.runtimeType.toString(),
  },
  'exception.message': _errorMessage(error),
};

/// Writes structured log records to the logger of the call it runs in.
///
/// ```dart
/// const _log = Logger('todo');
///
/// _log.info('todo.created', attributes: {'todo.id': todo.id});
/// ```
///
/// Inside a call of an app built with `observer: RpcLogger(...)`, records go
/// to that logger and carry the call's trace and span ids. Inside
/// [RpcLogger.run] they go to that logger. Elsewhere they go to
/// [RpcLogger.fallback].
final class Logger {
  const Logger(this.scope) : _target = null;

  const Logger._bound(this.scope, this._target);

  final String scope;
  final RpcLogger? _target;

  bool isEnabled(RpcLogSeverity severity) => _resolve().$1.isEnabled(severity);

  void trace(String message, {RpcAttributes attributes = const {}}) =>
      log(RpcLogSeverity.trace, message, attributes: attributes);

  void debug(String message, {RpcAttributes attributes = const {}}) =>
      log(RpcLogSeverity.debug, message, attributes: attributes);

  void info(String message, {RpcAttributes attributes = const {}}) =>
      log(RpcLogSeverity.info, message, attributes: attributes);

  void warn(
    String message, {
    RpcAttributes attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    RpcLogSeverity.warn,
    message,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );

  void error(
    String message, {
    RpcAttributes attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    RpcLogSeverity.error,
    message,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );

  void fatal(
    String message, {
    RpcAttributes attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    RpcLogSeverity.fatal,
    message,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );

  void log(
    RpcLogSeverity severity,
    String message, {
    RpcAttributes attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final (target, call) = _resolve();
    if (!target.isEnabled(severity)) {
      return;
    }
    target.emit(
      RpcLogRecord(
        timestamp: DateTime.now(),
        severity: severity,
        message: message,
        scope: scope,
        attributes: {
          ...attributes,
          if (error != null) ..._exceptionAttributes(error),
        },
        traceId: call?.trace.traceId,
        spanId: call?.trace.spanId,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  (RpcLogger, _CallObservation?) _resolve() {
    final call = switch (currentRpcCallObservation()) {
      final _CallObservation observation => observation,
      _ => null,
    };
    final ambient = switch (Zone.current[_ambientLoggerZoneKey]) {
      final RpcLogger logger => logger,
      _ => null,
    };
    return (_target ?? call?.logger ?? ambient ?? RpcLogger.fallback, call);
  }
}

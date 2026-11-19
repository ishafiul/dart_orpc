import 'dart:async';
import 'dart:isolate';

import 'telemetry_model.dart';

/// A failed export, carried back from the export isolate as text.
final class RpcExportFailure implements Exception {
  const RpcExportFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs exporters in their own isolate, so formatting and I/O never take CPU
/// time from the isolate that serves requests.
final class ExportWorker {
  ExportWorker._(this._replies, this._commands) {
    _replies.handler = _onReply;
  }

  final RawReceivePort _replies;
  final SendPort _commands;
  final Map<int, Completer<List<(String, String)>>> _pending = {};
  var _nextId = 0;

  /// Starts a worker that owns [exporters]. Returns null when the exporters
  /// cannot move to another isolate, such as one holding an open `IOSink`.
  static Future<ExportWorker?> spawn(
    List<RpcTelemetryExporter> exporters, {
    required Duration exportTimeout,
  }) async {
    final ready = Completer<SendPort>();
    final replies = RawReceivePort();
    replies.handler = (Object? message) {
      if (message is SendPort) {
        ready.complete(message);
      }
    };
    try {
      await Isolate.spawn(_workerMain, (
        replies.sendPort,
        exporters,
        exportTimeout,
      ), debugName: 'dart_orpc_logger export');
    } on ArgumentError {
      replies.close();
      return null;
    }
    final commands = await ready.future;
    replies.keepIsolateAlive = false;
    return ExportWorker._(replies, commands);
  }

  /// Exports [batch] in the worker. Returns the failures as error and
  /// stack-trace text.
  Future<List<(String, String)>> export(RpcTelemetryBatch batch) =>
      _request(_transferable(batch));

  /// Shuts the exporters down and stops the worker.
  Future<List<(String, String)>> shutdown() async {
    final failures = await _request(null);
    _replies.close();
    return failures;
  }

  Future<List<(String, String)>> _request(RpcTelemetryBatch? batch) {
    final id = _nextId++;
    final reply = Completer<List<(String, String)>>();
    _pending[id] = reply;
    _replies.keepIsolateAlive = true;
    _commands.send((id, batch));
    return reply.future;
  }

  void _onReply(Object? message) {
    if (message case (final int id, final List<(String, String)> failures)) {
      _pending.remove(id)?.complete(failures);
      if (_pending.isEmpty) {
        _replies.keepIsolateAlive = false;
      }
    }
  }
}

Future<void> _workerMain(
  (SendPort, List<RpcTelemetryExporter>, Duration) setup,
) async {
  final (replies, exporters, exportTimeout) = setup;
  final commands = ReceivePort();
  replies.send(commands.sendPort);
  await for (final message in commands) {
    if (message case (final int id, final RpcTelemetryBatch? batch)) {
      final failures = <(String, String)>[];
      Future<void> guarded(Future<void> Function() action) async {
        try {
          await action().timeout(exportTimeout);
        } on Object catch (error, stackTrace) {
          failures.add(('$error', '$stackTrace'));
        }
      }

      if (batch == null) {
        await Future.wait([
          for (final exporter in exporters) guarded(exporter.shutdown),
        ]);
        replies.send((id, failures));
        commands.close();
        return;
      }
      await Future.wait([
        for (final exporter in exporters) guarded(() => exporter.export(batch)),
      ]);
      replies.send((id, failures));
    }
  }
}

RpcTelemetryBatch _transferable(RpcTelemetryBatch batch) => RpcTelemetryBatch(
  resource: RpcTelemetryResource(
    serviceName: batch.resource.serviceName,
    serviceVersion: batch.resource.serviceVersion,
    environment: batch.resource.environment,
    attributes: _plainAttributes(batch.resource.attributes),
  ),
  logs: [for (final record in batch.logs) _transferableLog(record)],
  spans: [for (final span in batch.spans) _transferableSpan(span)],
);

RpcLogRecord _transferableLog(RpcLogRecord record) {
  final attributes = _plainAttributes(record.attributes);
  if (record.error == null &&
      record.stackTrace == null &&
      identical(attributes, record.attributes)) {
    return record;
  }
  return RpcLogRecord(
    timestamp: record.timestamp,
    severity: record.severity,
    message: record.message,
    scope: record.scope,
    attributes: attributes,
    traceId: record.traceId,
    spanId: record.spanId,
    error: record.error?.toString(),
    stackTrace: switch (record.stackTrace) {
      null => null,
      final stackTrace => StackTrace.fromString('$stackTrace'),
    },
  );
}

RpcSpanRecord _transferableSpan(RpcSpanRecord span) {
  final attributes = _plainAttributes(span.attributes);
  return identical(attributes, span.attributes) &&
          span.events.every(
            (event) =>
                identical(_plainAttributes(event.attributes), event.attributes),
          )
      ? span
      : RpcSpanRecord(
          traceId: span.traceId,
          spanId: span.spanId,
          parentSpanId: span.parentSpanId,
          name: span.name,
          start: span.start,
          end: span.end,
          status: span.status,
          statusMessage: span.statusMessage,
          attributes: attributes,
          events: [
            for (final event in span.events)
              RpcSpanEvent(
                timestamp: event.timestamp,
                name: event.name,
                attributes: _plainAttributes(event.attributes),
              ),
          ],
        );
}

RpcAttributes _plainAttributes(RpcAttributes attributes) {
  if (attributes.values.every(_isPlain)) {
    return attributes;
  }
  return {
    for (final MapEntry(:key, :value) in attributes.entries)
      key: _isPlain(value) ? value : value.toString(),
  };
}

bool _isPlain(Object? value) => switch (value) {
  null || String() || bool() || int() || double() => true,
  List() => value.every(_isPlain),
  _ => false,
};

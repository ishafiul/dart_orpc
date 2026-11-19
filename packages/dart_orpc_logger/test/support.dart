import 'dart:async';

import 'package:dart_orpc_logger/dart_orpc_logger.dart';

final class MemoryExporter implements RpcTelemetryExporter {
  final List<RpcLogRecord> logs = [];
  final List<RpcSpanRecord> spans = [];
  final List<RpcTelemetryBatch> batches = [];
  var shutdowns = 0;

  @override
  Future<void> export(RpcTelemetryBatch batch) async {
    batches.add(batch);
    logs.addAll(batch.logs);
    spans.addAll(batch.spans);
  }

  @override
  Future<void> shutdown() async => shutdowns++;

  Iterable<RpcLogRecord> scope(String name) =>
      logs.where((record) => record.scope == name);
}

final class HangingExporter implements RpcTelemetryExporter {
  final Completer<void> _never = Completer();
  var calls = 0;

  @override
  Future<void> export(RpcTelemetryBatch batch) {
    calls++;
    return _never.future;
  }

  @override
  Future<void> shutdown() async {}
}

final class FailingExporter implements RpcTelemetryExporter {
  @override
  Future<void> export(RpcTelemetryBatch batch) =>
      Future.error(StateError('collector down'));

  @override
  Future<void> shutdown() async {}
}

RpcLogRecord record(String message, {String scope = 'test'}) => RpcLogRecord(
  timestamp: DateTime.utc(2026),
  severity: RpcLogSeverity.info,
  message: message,
  scope: scope,
);

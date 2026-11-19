import 'dart:convert';
import 'dart:io';

import 'pretty_format.dart';
import 'telemetry_model.dart';

enum RpcConsoleFormat {
  /// One readable, optionally coloured line per record, for development.
  pretty,

  /// One JSON object per line, for log collectors.
  json,
}

/// Writes log records to a sink, [stdout] by default, one write per batch.
///
/// Spans are not printed: every call already produces an access log record,
/// and span data belongs in a tracing backend (see `RpcOtlpHttpExporter`).
final class RpcConsoleExporter implements RpcTelemetryExporter {
  RpcConsoleExporter({
    this.format = RpcConsoleFormat.pretty,
    IOSink? sink,
    bool? colors,
  }) : _customSink = sink,
       _colors =
           colors ??
           (format == RpcConsoleFormat.pretty &&
               sink == null &&
               stdout.supportsAnsiEscapes);

  RpcConsoleExporter.pretty({IOSink? sink, bool? colors})
    : this(sink: sink, colors: colors);

  RpcConsoleExporter.json({IOSink? sink})
    : this(format: RpcConsoleFormat.json, sink: sink);

  final RpcConsoleFormat format;

  final IOSink? _customSink;
  final bool _colors;

  IOSink get _sink => _customSink ?? stdout;

  @override
  Future<void> export(RpcTelemetryBatch batch) async {
    if (batch.logs.isEmpty) {
      return;
    }
    final buffer = StringBuffer();
    for (final record in batch.logs) {
      switch (format) {
        case RpcConsoleFormat.pretty:
          RpcPrettyFormat(colors: _colors).write(buffer, record);
        case RpcConsoleFormat.json:
          buffer.writeln(jsonEncode(_jsonRecord(batch.resource, record)));
      }
    }
    _sink.write(buffer);
  }

  @override
  Future<void> shutdown() => _sink.flush();

  Map<String, Object?> _jsonRecord(
    RpcTelemetryResource resource,
    RpcLogRecord record,
  ) => {
    'time': record.timestamp.toUtc().toIso8601String(),
    'level': record.severity.label,
    'severity_number': record.severity.number,
    'service': resource.serviceName,
    'scope': record.scope,
    'message': record.message,
    'trace_id': ?record.traceId,
    'span_id': ?record.spanId,
    if (record.attributes.isNotEmpty)
      'attributes': {
        for (final MapEntry(:key, :value) in record.attributes.entries)
          key: jsonSafe(value),
      },
    'stack_trace': ?record.stackTrace?.toString(),
  };
}

/// [value] as something `jsonEncode` accepts.
Object? jsonSafe(Object? value) => switch (value) {
  null || String() || bool() || int() => value,
  double() when value.isFinite => value,
  Iterable() => [for (final item in value) jsonSafe(item)],
  _ => value.toString(),
};

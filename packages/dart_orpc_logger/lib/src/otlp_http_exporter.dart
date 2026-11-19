import 'dart:convert';
import 'dart:io';

import 'telemetry_model.dart';

const _logsPath = 'v1/logs';
const _tracesPath = 'v1/traces';
const _serverSpanKind = 2;

/// Sends logs and spans to an OpenTelemetry collector with OTLP/HTTP, JSON
/// encoding: `POST {endpoint}/v1/logs` and `POST {endpoint}/v1/traces`.
///
/// Point [endpoint] at a collector or a backend that accepts OTLP, such as
/// `http://localhost:4318`. [headers] carry authentication, such as an API key.
final class RpcOtlpHttpExporter implements RpcTelemetryExporter {
  RpcOtlpHttpExporter({
    required this.endpoint,
    this.headers = const {},
    this.scopeName = 'dart_orpc_logger',
    HttpClient? client,
  }) : _injectedClient = client;

  final Uri endpoint;
  final Map<String, String> headers;

  /// The instrumentation scope of exported spans.
  final String scopeName;
  final HttpClient? _injectedClient;
  HttpClient? _ownClient;

  HttpClient get _client => _injectedClient ?? (_ownClient ??= HttpClient());

  @override
  Future<void> export(RpcTelemetryBatch batch) async {
    await Future.wait([
      if (batch.logs.isNotEmpty) _post(_logsPath, encodeOtlpLogs(batch)),
      if (batch.spans.isNotEmpty)
        _post(_tracesPath, encodeOtlpSpans(batch, scopeName: scopeName)),
    ]);
  }

  @override
  Future<void> shutdown() async => _ownClient?.close();

  Future<void> _post(String path, Map<String, Object?> body) async {
    final request = await _client.postUrl(_resolve(path));
    request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'OTLP export to ${request.uri} failed with ${response.statusCode}.',
        uri: request.uri,
      );
    }
  }

  Uri _resolve(String path) {
    final base = endpoint.path.endsWith('/')
        ? endpoint
        : endpoint.replace(path: '${endpoint.path}/');
    return base.resolve(path);
  }
}

/// [batch]'s log records as an OTLP `ExportLogsServiceRequest`.
Map<String, Object?> encodeOtlpLogs(RpcTelemetryBatch batch) {
  final byScope = <String, List<RpcLogRecord>>{};
  for (final record in batch.logs) {
    (byScope[record.scope] ??= []).add(record);
  }
  return {
    'resourceLogs': [
      {
        'resource': {'attributes': _attributes(batch.resource.toAttributes())},
        'scopeLogs': [
          for (final MapEntry(key: scope, value: records) in byScope.entries)
            {
              'scope': {'name': scope},
              'logRecords': [for (final record in records) _logRecord(record)],
            },
        ],
      },
    ],
  };
}

/// [batch]'s spans as an OTLP `ExportTraceServiceRequest`.
Map<String, Object?> encodeOtlpSpans(
  RpcTelemetryBatch batch, {
  required String scopeName,
}) => {
  'resourceSpans': [
    {
      'resource': {'attributes': _attributes(batch.resource.toAttributes())},
      'scopeSpans': [
        {
          'scope': {'name': scopeName},
          'spans': [for (final span in batch.spans) _span(span)],
        },
      ],
    },
  ],
};

Map<String, Object?> _logRecord(RpcLogRecord record) => {
  'timeUnixNano': _nanos(record.timestamp),
  'observedTimeUnixNano': _nanos(record.timestamp),
  'severityNumber': record.severity.number,
  'severityText': record.severity.label,
  'body': {'stringValue': record.message},
  'attributes': _attributes({
    ...record.attributes,
    'exception.stacktrace': ?record.stackTrace?.toString(),
  }),
  'traceId': ?record.traceId,
  'spanId': ?record.spanId,
};

Map<String, Object?> _span(RpcSpanRecord span) => {
  'traceId': span.traceId,
  'spanId': span.spanId,
  'parentSpanId': ?span.parentSpanId,
  'name': span.name,
  'kind': _serverSpanKind,
  'startTimeUnixNano': _nanos(span.start),
  'endTimeUnixNano': _nanos(span.end),
  'attributes': _attributes(span.attributes),
  'events': [
    for (final event in span.events)
      {
        'timeUnixNano': _nanos(event.timestamp),
        'name': event.name,
        'attributes': _attributes(event.attributes),
      },
  ],
  'status': {'code': span.status.index, 'message': ?span.statusMessage},
};

String _nanos(DateTime time) => '${time.microsecondsSinceEpoch * 1000}';

List<Map<String, Object?>> _attributes(RpcAttributes attributes) => [
  for (final MapEntry(:key, :value) in attributes.entries)
    if (value != null) {'key': key, 'value': _anyValue(value)},
];

Map<String, Object?> _anyValue(Object value) => switch (value) {
  String() => {'stringValue': value},
  bool() => {'boolValue': value},
  int() => {'intValue': '$value'},
  double() => {'doubleValue': value},
  Iterable() => {
    'arrayValue': {
      'values': [
        for (final item in value)
          if (item != null) _anyValue(item),
      ],
    },
  },
  _ => {'stringValue': value.toString()},
};

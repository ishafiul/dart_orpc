/// Log severities with their OpenTelemetry severity numbers.
enum RpcLogSeverity {
  trace(1, 'TRACE'),
  debug(5, 'DEBUG'),
  info(9, 'INFO'),
  warn(13, 'WARN'),
  error(17, 'ERROR'),
  fatal(21, 'FATAL');

  const RpcLogSeverity(this.number, this.label);

  /// The OpenTelemetry `severityNumber`.
  final int number;

  /// The OpenTelemetry `severityText`.
  final String label;

  bool isAtLeast(RpcLogSeverity other) => number >= other.number;
}

/// Attribute values: `String`, `bool`, `int`, `double`, or a list of those.
/// Other values are exported with `toString()`.
typedef RpcAttributes = Map<String, Object?>;

/// Describes the service that produces telemetry, as OpenTelemetry resource
/// attributes.
final class RpcTelemetryResource {
  const RpcTelemetryResource({
    required this.serviceName,
    this.serviceVersion,
    this.environment,
    this.attributes = const {},
  });

  final String serviceName;
  final String? serviceVersion;

  /// The deployment environment, such as `production` or `staging`.
  final String? environment;
  final RpcAttributes attributes;

  RpcAttributes toAttributes() => {
    'service.name': serviceName,
    'service.version': ?serviceVersion,
    'deployment.environment.name': ?environment,
    'telemetry.sdk.name': 'dart_orpc_logger',
    'telemetry.sdk.language': 'dart',
    ...attributes,
  };
}

/// One structured log record, shaped like an OpenTelemetry log record.
final class RpcLogRecord {
  const RpcLogRecord({
    required this.timestamp,
    required this.severity,
    required this.message,
    required this.scope,
    this.attributes = const {},
    this.traceId,
    this.spanId,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final RpcLogSeverity severity;
  final String message;

  /// The logger name, exported as the instrumentation scope.
  final String scope;
  final RpcAttributes attributes;
  final String? traceId;
  final String? spanId;
  final Object? error;
  final StackTrace? stackTrace;
}

enum RpcSpanStatus { unset, ok, error }

/// An event inside a span, such as an `exception`.
final class RpcSpanEvent {
  const RpcSpanEvent({
    required this.timestamp,
    required this.name,
    this.attributes = const {},
  });

  final DateTime timestamp;
  final String name;
  final RpcAttributes attributes;
}

/// One finished server span, shaped like an OpenTelemetry span.
final class RpcSpanRecord {
  const RpcSpanRecord({
    required this.traceId,
    required this.spanId,
    required this.name,
    required this.start,
    required this.end,
    this.parentSpanId,
    this.status = RpcSpanStatus.unset,
    this.statusMessage,
    this.attributes = const {},
    this.events = const [],
  });

  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String name;
  final DateTime start;
  final DateTime end;
  final RpcSpanStatus status;
  final String? statusMessage;
  final RpcAttributes attributes;
  final List<RpcSpanEvent> events;
}

/// Records handed to an exporter in one call.
final class RpcTelemetryBatch {
  const RpcTelemetryBatch({
    required this.resource,
    this.logs = const [],
    this.spans = const [],
  });

  final RpcTelemetryResource resource;
  final List<RpcLogRecord> logs;
  final List<RpcSpanRecord> spans;

  bool get isEmpty => logs.isEmpty && spans.isEmpty;
}

/// Sends batches somewhere: a console, a file, an OpenTelemetry collector.
///
/// [export] runs in the background, never on the request path. A failure is
/// counted and reported through `RpcLogger.onExportError`; the batch is not
/// retried.
abstract interface class RpcTelemetryExporter {
  Future<void> export(RpcTelemetryBatch batch);

  Future<void> shutdown();
}

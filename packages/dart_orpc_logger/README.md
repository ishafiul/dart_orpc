# dart_orpc_logger

Structured logging and tracing for dart_orpc apps, shaped like OpenTelemetry:
log records, server spans, W3C `traceparent` propagation, and export to the
console or to any OTLP collector. Most applications get it through the
[`dart_orpc`](../dart_orpc) facade.

## Turn it on

```dart
final telemetry = RpcLogger(
  resource: const RpcTelemetryResource(serviceName: 'todo-api'),
  exporters: [
    RpcConsoleExporter.pretty(),
    RpcOtlpHttpExporter(endpoint: Uri.parse('http://localhost:4318')),
  ],
);

final app = const AppModule().buildRpcApp(observer: telemetry);
```

That is the whole setup. Every HTTP exchange (RPC, REST, SSE) and every
WebSocket call then produces:

- an access log record: `POST /rpc todo.create 200 3.1ms`, as INFO, WARN for
  client errors, ERROR for server failures;
- an error record with the exception and stack trace for unexpected failures;
- a server span named after the RPC method, with OpenTelemetry semantic
  attributes (`rpc.method`, `http.route`, `http.response.status_code`, ...).

## Log from anywhere

```dart
const _log = Logger('todo');

_log.info('todo.created', attributes: {'todo.id': todo.id});
```

Inside a call, a `Logger` writes to the app's `RpcLogger` and carries that
call's trace and span ids, with nothing passed around. Outside a call, wrap
code in `telemetry.run(...)`, or use `telemetry.logger('startup')`.

## It never delays a response

- Recording appends to a bounded in-memory queue. When it is full, the oldest
  records are dropped and counted in `droppedRecords`; nothing blocks.
- Exporters run in batches in a background isolate, so formatting and I/O do
  not take CPU time from serving requests. Exporters that cannot move to
  another isolate (for example one given an open `IOSink`) run in the serving
  isolate instead; `backgroundExport: false` forces that.
- A slow exporter times out after `exportTimeout`; a failing one is counted in
  `exportFailures` and reported to `onExportError`. Batches are not retried.
- A throwing observer is counted as a hook error and the request is served
  normally.

Closing the app flushes the queue and shuts the exporters down.

## Options

| Option | Default | Purpose |
|---|---|---|
| `minSeverity` | `info` | Records below it are dropped before they are built into a batch |
| `accessLog` | `true` | One access record per call |
| `traces` | `true` | One span per sampled call |
| `traceSampleRatio` | `1.0` | Share of calls traced when the caller sent no sampling decision |
| `maxQueuedRecords` | `2048` | Queue bound before the oldest records are dropped |
| `maxBatchSize` | `512` | Records per export call |
| `flushInterval` | `1s` | Longest time a record waits before export |
| `exportTimeout` | `10s` | Longest time one export call may take |

## Write an exporter

Implement `RpcTelemetryExporter`. Keep its fields plain data and create sinks
or clients on first use, so the logger can move it to the export isolate.

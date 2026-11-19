import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_logger/dart_orpc_logger.dart';
import 'package:test/test.dart';

const _resource = RpcTelemetryResource(
  serviceName: 'todo-api',
  serviceVersion: '1.2.0',
  environment: 'test',
);
const _traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
const _spanId = '00f067aa0ba902b7';

final _log = RpcLogRecord(
  timestamp: DateTime.utc(2026, 11, 19, 10),
  severity: RpcLogSeverity.warn,
  message: 'todo.slow',
  scope: 'todo',
  attributes: {
    'todo.id': 7,
    'todo.tags': ['a', 'b'],
    'ratio': 0.5,
  },
  traceId: _traceId,
  spanId: _spanId,
);

final _span = RpcSpanRecord(
  traceId: _traceId,
  spanId: _spanId,
  parentSpanId: 'b7ad6b7169203331',
  name: 'todo.create',
  start: DateTime.utc(2026, 11, 19, 10),
  end: DateTime.utc(2026, 11, 19, 10, 0, 0, 12),
  status: RpcSpanStatus.error,
  statusMessage: 'boom',
  attributes: {'http.response.status_code': 500},
  events: [
    RpcSpanEvent(
      timestamp: DateTime.utc(2026, 11, 19, 10, 0, 0, 12),
      name: 'exception',
      attributes: {'exception.type': 'StateError'},
    ),
  ],
);

final class _CapturingSink {
  final _controller = StreamController<List<int>>();
  late final IOSink sink = IOSink(_controller.sink);
  late final Future<String> text = _controller.stream
      .transform(utf8.decoder)
      .join();

  Future<String> close() async {
    final written = text;
    await sink.close();
    return written;
  }
}

void main() {
  group('Given the console exporter', () {
    test(
      'When the format is JSON then one JSON object is written per record',
      () async {
        final capture = _CapturingSink();
        final exporter = RpcConsoleExporter.json(sink: capture.sink);

        await exporter.export(
          RpcTelemetryBatch(resource: _resource, logs: [_log, _log]),
        );

        final lines = const LineSplitter().convert(await capture.close());
        expect(lines, hasLength(2));
        expect(jsonDecode(lines.first), {
          'time': '2026-11-19T10:00:00.000Z',
          'level': 'WARN',
          'severity_number': 13,
          'service': 'todo-api',
          'scope': 'todo',
          'message': 'todo.slow',
          'trace_id': _traceId,
          'span_id': _spanId,
          'attributes': {
            'todo.id': 7,
            'todo.tags': ['a', 'b'],
            'ratio': 0.5,
          },
        });
      },
    );

    test('When the batch holds only spans then nothing is written', () async {
      final capture = _CapturingSink();
      final exporter = RpcConsoleExporter.json(sink: capture.sink);

      await exporter.export(
        RpcTelemetryBatch(resource: _resource, spans: [_span]),
      );

      expect(await capture.close(), isEmpty);
    });
  });

  group('Given OTLP encoding', () {
    test('When logs are encoded then they follow ExportLogsServiceRequest', () {
      final encoded = encodeOtlpLogs(
        RpcTelemetryBatch(resource: _resource, logs: [_log]),
      );

      final resourceLogs = (encoded['resourceLogs']! as List).single as Map;
      expect(
        (resourceLogs['resource'] as Map)['attributes'],
        containsAll([
          {
            'key': 'service.name',
            'value': {'stringValue': 'todo-api'},
          },
          {
            'key': 'service.version',
            'value': {'stringValue': '1.2.0'},
          },
        ]),
      );
      final scopeLogs = (resourceLogs['scopeLogs'] as List).single as Map;
      expect(scopeLogs['scope'], {'name': 'todo'});
      expect((scopeLogs['logRecords'] as List).single, {
        'timeUnixNano': '1795082400000000000',
        'observedTimeUnixNano': '1795082400000000000',
        'severityNumber': 13,
        'severityText': 'WARN',
        'body': {'stringValue': 'todo.slow'},
        'attributes': [
          {
            'key': 'todo.id',
            'value': {'intValue': '7'},
          },
          {
            'key': 'todo.tags',
            'value': {
              'arrayValue': {
                'values': [
                  {'stringValue': 'a'},
                  {'stringValue': 'b'},
                ],
              },
            },
          },
          {
            'key': 'ratio',
            'value': {'doubleValue': 0.5},
          },
        ],
        'traceId': _traceId,
        'spanId': _spanId,
      });
    });

    test(
      'When spans are encoded then they follow ExportTraceServiceRequest',
      () {
        final encoded = encodeOtlpSpans(
          RpcTelemetryBatch(resource: _resource, spans: [_span]),
          scopeName: 'dart_orpc_logger',
        );

        final scopeSpans =
            (((encoded['resourceSpans']! as List).single as Map)['scopeSpans']
                        as List)
                    .single
                as Map;
        expect(scopeSpans['scope'], {'name': 'dart_orpc_logger'});
        expect((scopeSpans['spans'] as List).single, {
          'traceId': _traceId,
          'spanId': _spanId,
          'parentSpanId': 'b7ad6b7169203331',
          'name': 'todo.create',
          'kind': 2,
          'startTimeUnixNano': '1795082400000000000',
          'endTimeUnixNano': '1795082400012000000',
          'attributes': [
            {
              'key': 'http.response.status_code',
              'value': {'intValue': '500'},
            },
          ],
          'events': [
            {
              'timeUnixNano': '1795082400012000000',
              'name': 'exception',
              'attributes': [
                {
                  'key': 'exception.type',
                  'value': {'stringValue': 'StateError'},
                },
              ],
            },
          ],
          'status': {'code': 2, 'message': 'boom'},
        });
      },
    );
  });

  group('Given an OTLP collector over HTTP', () {
    late HttpServer collector;
    late List<(String, String?, Object?)> received;
    var status = HttpStatus.ok;

    setUp(() async {
      received = [];
      status = HttpStatus.ok;
      collector = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      collector.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        received.add((
          request.uri.path,
          request.headers.value('api-key'),
          jsonDecode(body),
        ));
        request.response.statusCode = status;
        await request.response.close();
      });
    });

    tearDown(() => collector.close(force: true));

    Uri endpoint() => Uri.parse('http://127.0.0.1:${collector.port}/otel');

    test(
      'When a batch is exported then logs and spans are posted with headers',
      () async {
        final exporter = RpcOtlpHttpExporter(
          endpoint: endpoint(),
          headers: {'api-key': 'secret'},
        );

        await exporter.export(
          RpcTelemetryBatch(resource: _resource, logs: [_log], spans: [_span]),
        );
        await exporter.shutdown();

        expect(
          received.map((request) => (request.$1, request.$2)),
          unorderedEquals([
            ('/otel/v1/logs', 'secret'),
            ('/otel/v1/traces', 'secret'),
          ]),
        );
      },
    );

    test('When the collector rejects a batch then the export fails', () async {
      status = HttpStatus.serviceUnavailable;
      final exporter = RpcOtlpHttpExporter(endpoint: endpoint());

      await expectLater(
        exporter.export(RpcTelemetryBatch(resource: _resource, logs: [_log])),
        throwsA(isA<HttpException>()),
      );
      await exporter.shutdown();
    });
  });
}

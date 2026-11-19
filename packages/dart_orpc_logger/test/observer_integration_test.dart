import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:dart_orpc_logger/dart_orpc_logger.dart';
import 'package:test/test.dart';

import 'support.dart';

const _traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
const _parentSpanId = '00f067aa0ba902b7';
const _itemLog = Logger('item');

RpcProcedure<Null, JsonObject> _procedure(
  String method,
  JsonObject Function() handler,
) => RpcProcedure<Null, JsonObject>(
  method: method,
  metadata: ProcedureMetadata(
    rpcMethod: method,
    controllerNamespace: 'item',
    methodName: method.split('.').last,
    outputTypeCode: 'JsonObject',
  ),
  decodeInput: (_) => null,
  encodeOutput: (value) => value,
  handler: (_, _) => handler(),
);

RpcHttpApp _app(RpcObserver observer) => RpcHttpApp(
  procedures: RpcProcedureRegistry([
    _procedure('item.get', () {
      _itemLog.info('item.loaded', attributes: {'item.id': 1});
      return {'id': 1};
    }),
    _procedure(
      'item.missing',
      () => throw RpcException.notFound('Item was not found.'),
    ),
    _procedure('item.broken', () => throw StateError('invariant broken')),
  ]),
  observer: observer,
);

void main() {
  late RpcHttpServer server;
  late HttpClient client;
  late MemoryExporter exporter;
  late RpcLogger logger;

  Future<void> start(RpcLogger observer) async {
    logger = observer;
    server = await _app(observer).listen(0, hostname: '127.0.0.1');
    client = HttpClient();
  }

  Future<int> call(
    String method, {
    Map<String, String> headers = const {},
  }) async {
    final request = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.port}/rpc'),
    );
    headers.forEach(request.headers.set);
    request.write(jsonEncode({'method': method}));
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  }

  Future<void> stop() async {
    client.close(force: true);
    await server.close();
  }

  group('Given an app observed by an RpcLogger', () {
    setUp(() async {
      exporter = MemoryExporter();
      await start(RpcLogger(backgroundExport: false, exporters: [exporter]));
    });

    test('When a procedure logs then its record carries the call trace and the call gets an access record and a span', () async {
      expect(await call('item.get'), HttpStatus.ok);
      await stop();

      final itemRecord = exporter.scope('item').single;
      final access = exporter.scope('dart_orpc.access').single;
      final span = exporter.spans.single;
      expect(itemRecord.attributes, {'item.id': 1});
      expect(itemRecord.traceId, span.traceId);
      expect(itemRecord.spanId, span.spanId);
      expect(access.severity, RpcLogSeverity.info);
      expect(
        access.message,
        matches(RegExp(r'^POST /rpc item\.get 200 \d+\.\dms$')),
      );
      expect(span.name, 'item.get');
      expect(span.status, RpcSpanStatus.unset);
      expect(span.attributes, containsPair('rpc.method', 'item.get'));
      expect(span.attributes, containsPair('http.response.status_code', 200));
      expect(span.attributes, containsPair('http.route', '/rpc'));
    });

    test(
      'When the caller sends a traceparent then the call joins that trace',
      () async {
        await call(
          'item.get',
          headers: {'traceparent': '00-$_traceId-$_parentSpanId-01'},
        );
        await stop();

        final span = exporter.spans.single;
        expect(span.traceId, _traceId);
        expect(span.parentSpanId, _parentSpanId);
        expect(span.spanId, isNot(_parentSpanId));
      },
    );

    test('When the caller sends an unsampled traceparent then no span is recorded but access logs remain', () async {
      await call(
        'item.get',
        headers: {'traceparent': '00-$_traceId-$_parentSpanId-00'},
      );
      await stop();

      expect(exporter.spans, isEmpty);
      expect(exporter.scope('dart_orpc.access').single.traceId, _traceId);
    });

    test('When a procedure fails with a client error then it is a warning without an error record', () async {
      expect(await call('item.missing'), HttpStatus.notFound);
      await stop();

      final access = exporter.scope('dart_orpc.access').single;
      expect(access.severity, RpcLogSeverity.warn);
      expect(access.attributes, containsPair('error.type', 'NOT_FOUND'));
      expect(exporter.scope('dart_orpc.error'), isEmpty);
      expect(exporter.spans.single.status, RpcSpanStatus.unset);
    });

    test('When a procedure fails unexpectedly then an error record and an error span are recorded', () async {
      expect(await call('item.broken'), HttpStatus.internalServerError);
      await stop();

      final error = exporter.scope('dart_orpc.error').single;
      final span = exporter.spans.single;
      expect(error.severity, RpcLogSeverity.error);
      expect(error.attributes, containsPair('exception.type', 'StateError'));
      expect(error.stackTrace, isNotNull);
      expect(error.traceId, span.traceId);
      expect(
        exporter.scope('dart_orpc.access').single.severity,
        RpcLogSeverity.error,
      );
      expect(span.status, RpcSpanStatus.error);
      expect(span.events.single.name, 'exception');
    });

    test(
      'When the server closes then the logger is flushed and shut down',
      () async {
        await call('item.get');
        await stop();

        expect(exporter.shutdowns, 1);
        expect(logger.droppedRecords, 0);
      },
    );
  });

  group('Given an exporter that never finishes', () {
    test('When requests arrive then responses are not delayed', () async {
      final hanging = HangingExporter();
      await start(
        RpcLogger(
          backgroundExport: false,
          exporters: [hanging],
          maxBatchSize: 1,
          exportTimeout: const Duration(milliseconds: 100),
        ),
      );
      final watch = Stopwatch()..start();
      for (var index = 0; index < 20; index++) {
        expect(await call('item.get'), HttpStatus.ok);
      }
      watch.stop();
      await stop();

      expect(hanging.calls, greaterThan(0));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });
  });

  group('Given an observer that throws', () {
    test('When requests arrive then they are served normally', () async {
      server = await _app(_ThrowingObserver()).listen(0, hostname: '127.0.0.1');
      client = HttpClient();

      expect(await call('item.get'), HttpStatus.ok);
      expect(await call('item.broken'), HttpStatus.internalServerError);
      await stop();
    });
  });
}

final class _ThrowingObserver implements RpcObserver {
  @override
  RpcCallObservation startCall(RpcObservedCallStart start) =>
      throw StateError('observer broken');

  @override
  void serverStarted(RpcObservedServer server) =>
      throw StateError('observer broken');

  @override
  void serverStopped(RpcObservedServer server) =>
      throw StateError('observer broken');

  @override
  Future<void> close() async {}
}

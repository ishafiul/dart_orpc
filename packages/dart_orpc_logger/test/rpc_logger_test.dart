import 'package:dart_orpc_logger/dart_orpc_logger.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('Given an RpcLogger', () {
    test(
      'When records are below the minimum severity then they are not exported',
      () async {
        final exporter = MemoryExporter();
        final logger = RpcLogger(
          backgroundExport: false,
          exporters: [exporter],
          minSeverity: RpcLogSeverity.warn,
        );

        logger.logger('todo')
          ..info('skipped')
          ..warn('kept')
          ..error('kept too');
        await logger.close();

        expect(exporter.logs.map((log) => log.message), ['kept', 'kept too']);
      },
    );

    test(
      'When a Logger runs inside run() then it writes to that logger',
      () async {
        final exporter = MemoryExporter();
        final logger = RpcLogger(
          backgroundExport: false,
          exporters: [exporter],
        );

        logger.run(
          () =>
              const Logger('startup')
                  .info('listening', attributes: {'server.port': 8080}),
        );
        await logger.close();

        final written = exporter.scope('startup').single;
        expect(written.message, 'listening');
        expect(written.attributes, {'server.port': 8080});
        expect(written.traceId, isNull);
      },
    );

    test(
      'When a Logger records an error then exception attributes are added',
      () async {
        final exporter = MemoryExporter();
        final logger = RpcLogger(
          backgroundExport: false,
          exporters: [exporter],
        );
        final failure = StateError('broken');

        logger.logger('job').error('job.failed', error: failure);
        await logger.close();

        expect(exporter.logs.single.attributes, {
          'exception.type': 'StateError',
          'exception.message': failure.toString(),
        });
        expect(exporter.logs.single.error, same(failure));
      },
    );

    test(
      'When the queue is full then the oldest records are dropped and counted',
      () async {
        final exporter = MemoryExporter();
        final logger = RpcLogger(
          backgroundExport: false,
          exporters: [exporter],
          maxQueuedRecords: 3,
          maxBatchSize: 10,
          flushInterval: const Duration(hours: 1),
        );

        for (final message in ['1', '2', '3', '4', '5']) {
          logger.emit(record(message));
        }
        await logger.close();

        expect(exporter.logs.map((log) => log.message), ['3', '4', '5']);
        expect(logger.droppedRecords, 2);
      },
    );

    test('When a batch fills up then it is exported without waiting for the interval', () async {
      final exporter = MemoryExporter();
      final logger = RpcLogger(
        backgroundExport: false,
        exporters: [exporter],
        maxBatchSize: 2,
        flushInterval: const Duration(hours: 1),
      );

      logger
        ..emit(record('a'))
        ..emit(record('b'));
      await Future<void>.value();
      await logger.flush();

      expect(exporter.batches.single.logs, hasLength(2));
      await logger.close();
    });

    test(
      'When the flush interval passes then queued records are exported',
      () async {
        final exporter = MemoryExporter();
        final logger = RpcLogger(
          backgroundExport: false,
          exporters: [exporter],
          flushInterval: const Duration(milliseconds: 10),
        );

        logger.emit(record('later'));
        await expectLater(
          Stream.periodic(const Duration(milliseconds: 5), (_) => exporter.logs)
              .firstWhere((logs) => logs.isNotEmpty)
              .timeout(const Duration(seconds: 2)),
          completes,
        );
        await logger.close();
      },
    );

    test('When closed then queued records are exported, exporters shut down, and later records dropped', () async {
      final exporter = MemoryExporter();
      final logger = RpcLogger(
        backgroundExport: false,
        exporters: [exporter],
        flushInterval: const Duration(hours: 1),
      );

      logger.emit(record('queued'));
      await logger.close();
      logger.emit(record('too late'));

      expect(exporter.logs.map((log) => log.message), ['queued']);
      expect(exporter.shutdowns, 1);
      expect(logger.droppedRecords, 1);
    });

    test(
      'When an exporter fails then the failure is counted and reported',
      () async {
        final reported = <Object>[];
        final logger = RpcLogger(
          backgroundExport: false,
          exporters: [FailingExporter()],
          onExportError: (error, _) => reported.add(error),
        );

        logger.emit(record('lost'));
        await logger.close();

        expect(logger.exportFailures, 1);
        expect(reported.single, isA<StateError>());
      },
    );

    test('When an exporter hangs then the export times out and other exporters still receive the batch', () async {
      final healthy = MemoryExporter();
      final logger = RpcLogger(
        backgroundExport: false,
        exporters: [HangingExporter(), healthy],
        exportTimeout: const Duration(milliseconds: 50),
      );

      logger.emit(record('delivered'));
      await logger.close().timeout(const Duration(seconds: 2));

      expect(healthy.logs.single.message, 'delivered');
      expect(logger.exportFailures, 1);
    });

    test(
      'When sizes or the sample ratio are invalid then construction fails',
      () {
        expect(() => RpcLogger(maxQueuedRecords: 0), throwsArgumentError);
        expect(() => RpcLogger(maxBatchSize: 0), throwsArgumentError);
        expect(() => RpcLogger(traceSampleRatio: 1.5), throwsArgumentError);
      },
    );
  });
}

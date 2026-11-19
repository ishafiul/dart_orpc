import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_logger/dart_orpc_logger.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('Given exporters running in the background isolate', () {
    late HttpServer collector;
    late List<String> paths;
    var status = HttpStatus.ok;

    setUp(() async {
      paths = [];
      status = HttpStatus.ok;
      collector = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      collector.listen((request) async {
        await utf8.decoder.bind(request).join();
        paths.add(request.uri.path);
        request.response.statusCode = status;
        await request.response.close();
      });
    });

    tearDown(() => collector.close(force: true));

    RpcLogger logger({void Function(Object, StackTrace)? onExportError}) =>
        RpcLogger(
          exporters: [
            RpcOtlpHttpExporter(
              endpoint: Uri.parse('http://127.0.0.1:${collector.port}'),
            ),
          ],
          onExportError: onExportError,
        );

    test('When records are flushed then the worker exports them', () async {
      final background = logger();

      background.logger('job').info('job.done', attributes: {'job.id': 3});
      await background.close();

      expect(paths, ['/v1/logs']);
      expect(background.exportFailures, 0);
    });

    test(
      'When the worker export fails then the failure is reported here',
      () async {
        status = HttpStatus.badGateway;
        final failures = <Object>[];
        final background = logger(
          onExportError: (error, _) => failures.add(error),
        );

        background.logger('job').info('job.done');
        await background.close();

        expect(background.exportFailures, 1);
        expect(failures.single, isA<RpcExportFailure>());
        expect('${failures.single}', contains('502'));
      },
    );

    test('When a record holds values other isolates cannot receive then it is still exported', () async {
      final background = logger();

      background
          .logger('job')
          .error(
            'job.failed',
            attributes: {'job.handle': Object()},
            error: StateError('boom'),
            stackTrace: StackTrace.current,
          );
      await background.close();

      expect(paths, ['/v1/logs']);
      expect(background.exportFailures, 0);
    });
  });

  group('Given an exporter that cannot move to another isolate', () {
    test('When records are flushed then it exports in this isolate', () async {
      final controller = StreamController<List<int>>();
      final written = controller.stream.transform(utf8.decoder).join();
      final sink = IOSink(controller.sink);
      final logger = RpcLogger(
        exporters: [RpcConsoleExporter.json(sink: sink)],
      );

      logger.emit(record('local'));
      await logger.close();
      await sink.close();

      expect(
        jsonDecode((await written).trim()),
        containsPair('message', 'local'),
      );
    });
  });
}

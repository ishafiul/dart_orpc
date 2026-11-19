import 'dart:io';

import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  test('When reading mapped values then types and defaults are resolved', () {
    final env = EnvReader.fromMap({
      'SECRET': ' value ',
      'SECONDS': '60',
      'PORT': '4000',
    });

    expect(env.requiredString('SECRET'), 'value');
    expect(env.required('SECRET'), 'value');
    expect(env.string('NAME', fallback: 'app'), 'app');
    expect(env.positiveInt('SECONDS', fallback: 30), 60);
    expect(
      env.duration('SECONDS', fallback: const Duration(seconds: 30)),
      const Duration(seconds: 60),
    );
    expect(env.port('PORT', fallback: 3000), 4000);
  });

  test(
    'When values are missing or invalid then descriptive errors surface',
    () {
      final env = EnvReader.fromMap({'SECONDS': 'invalid', 'PORT': '70000'});

      expect(() => env.requiredString('SECRET'), throwsA(isA<StateError>()));
      expect(() => env.required('SECRET'), throwsA(isA<StateError>()));
      expect(
        () => env.positiveInt('SECONDS', fallback: 30),
        throwsA(isA<StateError>()),
      );
      expect(
        () => env.port('PORT', fallback: 3000),
        throwsA(isA<StateError>()),
      );
      expect(
        () => env.duration('SECONDS', fallback: const Duration(seconds: 30)),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('When reading an optional URI then unset is null, valid parses and invalid fails', () {
    final env = EnvReader.fromMap({
      'OTLP': ' http://collector:4318 ',
      'RELATIVE': 'collector:4318/path',
      'FTP': 'ftp://collector',
    });

    expect(env.optionalUri('MISSING'), isNull);
    expect(env.optionalUri('OTLP'), Uri.parse('http://collector:4318'));
    expect(() => env.optionalUri('RELATIVE'), throwsA(isA<StateError>()));
    expect(() => env.optionalUri('FTP'), throwsA(isA<StateError>()));
  });

  group('Given EnvReader.load', () {
    late Directory directory;
    late _Capture capture;
    late RpcLogger logger;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('dart-orpc-env');
      capture = _Capture();
      logger = RpcLogger(
        backgroundExport: false,
        minSeverity: RpcLogSeverity.debug,
        exporters: [capture],
      );
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('When the file is missing then it logs env.file_missing and still reads the process environment', () async {
      final path = '${directory.path}/.env';

      final env = logger.run(() => EnvReader.load(path: path));
      await logger.close();

      expect(env.string('PATH', fallback: ''), isNotEmpty);
      expect(capture.logs.single.message, 'env.file_missing');
      expect(capture.logs.single.severity, RpcLogSeverity.info);
      expect(capture.logs.single.attributes, {'env.file': path});
    });

    test('When the file exists then its values are read and the load is logged at debug level', () async {
      final file = File('${directory.path}/.env')
        ..writeAsStringSync('APP_NAME=from-file\n');

      final env = logger.run(() => EnvReader.load(path: file.path));
      await logger.close();

      expect(env.string('APP_NAME', fallback: 'missing'), 'from-file');
      expect(capture.logs.single.message, 'env.file_loaded');
      expect(capture.logs.single.severity, RpcLogSeverity.debug);
    });
  });
}

final class _Capture implements RpcTelemetryExporter {
  final List<RpcLogRecord> logs = [];

  @override
  Future<void> export(RpcTelemetryBatch batch) async => logs.addAll(batch.logs);

  @override
  Future<void> shutdown() async {}
}

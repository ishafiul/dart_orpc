import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('Given health and metrics endpoints', () {
    test(
      'When health checks pass or fail then status reflects readiness',
      () async {
        final healthy = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          health: RpcHttpHealthOptions(check: () async => true),
        );
        final unhealthy = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          health: RpcHttpHealthOptions(check: () => false),
        );
        final throwing = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          health: RpcHttpHealthOptions(check: () => throw StateError('down')),
        );

        final healthyResponse = await healthy(
          const RpcHttpRequest(method: 'GET', path: '/health'),
        );
        final unhealthyResponse = await unhealthy(
          const RpcHttpRequest(method: 'GET', path: '/health'),
        );
        final throwingResponse = await throwing(
          const RpcHttpRequest(method: 'GET', path: '/health'),
        );

        expect(healthyResponse.statusCode, HttpStatus.ok);
        expect(
          jsonDecode(healthyResponse.body! as String),
          containsPair('status', 'up'),
        );
        expect(unhealthyResponse.statusCode, HttpStatus.serviceUnavailable);
        expect(throwingResponse.statusCode, HttpStatus.serviceUnavailable);
      },
    );

    test(
      'When endpoint methods are invalid then allow headers are returned',
      () async {
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          health: const RpcHttpHealthOptions(),
          metrics: const RpcHttpMetricsOptions(),
        );

        final health = await handler(
          const RpcHttpRequest(method: 'POST', path: '/health'),
        );
        final metrics = await handler(
          const RpcHttpRequest(method: 'POST', path: '/metrics'),
        );

        expect(health.statusCode, HttpStatus.methodNotAllowed);
        expect(health.headers['allow'], 'GET');
        expect(metrics.statusCode, HttpStatus.methodNotAllowed);
        expect(metrics.headers['allow'], 'GET');
      },
    );

    test(
      'When metrics are requested then process values are emitted',
      () async {
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          metrics: const RpcHttpMetricsOptions(),
        );

        final response = await handler(
          const RpcHttpRequest(method: 'GET', path: '/metrics'),
        );
        final body =
            jsonDecode(response.body! as String) as Map<String, Object?>;

        expect(response.statusCode, HttpStatus.ok);
        expect(body['pid'], isA<int>());
        expect(body['memory_usage'], isA<int>());
        expect(body['uptime_seconds'], isA<int>());
      },
    );
  });

  group('Given optional documentation endpoints', () {
    test(
      'When content is absent then docs and OpenAPI return not found',
      () async {
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
        );

        final docs = await handler(
          const RpcHttpRequest(method: 'GET', path: '/docs'),
        );
        final openApi = await handler(
          const RpcHttpRequest(method: 'GET', path: '/openapi.json'),
        );

        expect(docs.statusCode, HttpStatus.notFound);
        expect(openApi.statusCode, HttpStatus.notFound);
      },
    );

    test(
      'When methods are invalid then configured endpoints reject them',
      () async {
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          docsHtml: '<html></html>',
          openApiDocument: const {},
        );

        final docs = await handler(
          const RpcHttpRequest(method: 'POST', path: '/docs'),
        );
        final openApi = await handler(
          const RpcHttpRequest(method: 'POST', path: '/openapi.json'),
        );

        expect(docs.statusCode, HttpStatus.methodNotAllowed);
        expect(openApi.statusCode, HttpStatus.methodNotAllowed);
      },
    );

    test(
      'When basic authorization is malformed then docs remain protected',
      () async {
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          docsHtml: '<html></html>',
          docsBasicAuth: const RpcHttpBasicAuth(
            username: 'admin',
            password: 'secret',
          ),
        );
        final credentials = [
          'Bearer token',
          'Basic ',
          'Basic invalid-base64',
          'Basic ${base64Encode(utf8.encode('missing-separator'))}',
          'Basic ${base64Encode(utf8.encode('admin:wrong'))}',
        ];

        for (final authorization in credentials) {
          final response = await handler(
            RpcHttpRequest(
              method: 'GET',
              path: '/docs',
              headers: {'authorization': authorization},
            ),
          );
          expect(response.statusCode, HttpStatus.unauthorized);
        }
      },
    );
  });

  group('Given static file options', () {
    test(
      'When HEAD is used then metadata is returned without a body',
      () async {
        final directory = Directory.systemTemp.createTempSync('orpc-head');
        addTearDown(() => directory.deleteSync(recursive: true));
        File('${directory.path}/app.json').writeAsStringSync('{"ok":true}');
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          staticAssets: RpcHttpStaticOptions(
            directory: directory.path,
            path: '/assets',
          ),
        );

        final response = await handler(
          const RpcHttpRequest(method: 'HEAD', path: '/assets/app.json'),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(response.body, isNull);
        expect(response.headers['content-type'], contains('application/json'));
      },
    );

    test(
      'When method or file state is invalid then static handling is safe',
      () async {
        final directory = Directory.systemTemp.createTempSync('orpc-static');
        addTearDown(() => directory.deleteSync(recursive: true));
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          staticAssets: RpcHttpStaticOptions(
            directory: directory.path,
            path: '/assets',
          ),
        );

        final wrongMethod = await handler(
          const RpcHttpRequest(method: 'POST', path: '/assets/file.txt'),
        );
        final missing = await handler(
          const RpcHttpRequest(method: 'GET', path: '/assets/missing.txt'),
        );

        expect(wrongMethod.statusCode, HttpStatus.methodNotAllowed);
        expect(wrongMethod.headers['allow'], 'GET, HEAD');
        expect(missing.statusCode, HttpStatus.notFound);
      },
    );

    test(
      'When common asset extensions are served then content types are explicit',
      () async {
        final directory = Directory.systemTemp.createTempSync('orpc-types');
        addTearDown(() => directory.deleteSync(recursive: true));
        final expectedTypes = <String, String>{
          'index.html': 'text/html',
          'app.js': 'application/javascript',
          'app.css': 'text/css',
          'image.png': 'image/png',
          'image.jpg': 'image/jpeg',
          'image.gif': 'image/gif',
          'image.svg': 'image/svg+xml',
          'favicon.ico': 'image/x-icon',
          'readme.txt': 'text/plain',
          'payload.bin': 'application/octet-stream',
        };
        for (final name in expectedTypes.keys) {
          File('${directory.path}/$name').writeAsStringSync('content');
        }
        final nested = Directory('${directory.path}/nested')..createSync();
        File('${nested.path}/index.html').writeAsStringSync('nested');
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          staticAssets: RpcHttpStaticOptions(
            directory: directory.path,
            path: '/assets',
          ),
        );

        for (final entry in expectedTypes.entries) {
          final response = await handler(
            RpcHttpRequest(method: 'GET', path: '/assets/${entry.key}'),
          );
          expect(response.statusCode, HttpStatus.ok);
          expect(response.headers['content-type'], contains(entry.value));
        }
        final indexResponse = await handler(
          const RpcHttpRequest(method: 'GET', path: '/assets/nested'),
        );
        expect(indexResponse.statusCode, HttpStatus.ok);
        expect(utf8.decode(indexResponse.body! as List<int>), 'nested');
      },
    );
  });
}

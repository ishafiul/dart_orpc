import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('Given a running RpcHttpApp', () {
    late HttpServer server;
    late Uri baseUri;

    setUp(() async {
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry([
          RpcProcedure<JsonObject, JsonObject>(
            method: 'meta.echo',
            decodeInput: (rawInput) =>
                expectJsonObject(rawInput, context: 'meta.echo input'),
            encodeOutput: (output) => output,
            handler: (context, input) async {
              return {
                'httpMethod': context.httpMethod,
                'path': context.path,
                'traceId': context.headers['x-trace-id'],
                'input': input,
              };
            },
          ),
        ]),
        restRoutes: RestRouteRegistry([
          RestRoute(
            method: 'GET',
            path: '/meta/users/:id',
            handler: (context, request, pathParameters) async {
              final id = decodeRestScalarParameter<String>(
                rawValue: pathParameters['id'],
                source: 'path parameter',
                name: 'id',
                route: 'GET /meta/users/:id',
              );
              final include = decodeRestScalarParameter<String?>(
                rawValue: request.queryParameters['include'],
                source: 'query parameter',
                name: 'include',
                route: 'GET /meta/users/:id',
              );
              return {
                'httpMethod': context.httpMethod,
                'path': context.path,
                'traceId': context.headers['x-trace-id'],
                'id': id,
                'include': include,
              };
            },
          ),
        ]),
        openApiDocument: const {
          'openapi': '3.0.3',
          'info': {'title': 'Meta API', 'version': '1.0.0'},
          'paths': {},
          'components': {'schemas': {}},
        },
        docsHtml: '<html><body>Meta Docs</body></html>',
      );

      server = await app.listen(
        0,
        hostname: InternetAddress.loopbackIPv4.address,
      );
      baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'When POSTing to /rpc then it returns the RPC success envelope',
      () async {
        final response = await _send(
          baseUri.resolve('/rpc'),
          method: 'POST',
          headers: const {'x-trace-id': 'trace-1'},
          body: jsonEncode({
            'method': 'meta.echo',
            'input': {'id': '1'},
          }),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(
          response.headers.value('content-type'),
          contains('application/json'),
        );
        expect(jsonDecode(response.body), {
          'data': {
            'httpMethod': 'POST',
            'path': '/rpc',
            'traceId': 'trace-1',
            'input': {'id': '1'},
          },
        });
      },
    );

    test(
      'When sending a non-POST request to /rpc then it returns method not allowed',
      () async {
        final response = await _send(baseUri.resolve('/rpc'), method: 'GET');

        expect(response.statusCode, HttpStatus.methodNotAllowed);
        expect(response.headers.value('allow'), 'POST');
        expect(jsonDecode(response.body), {
          'error': {
            'code': 'BAD_REQUEST',
            'message': 'RPC endpoint only accepts POST requests.',
          },
        });
      },
    );

    test(
      'When requesting a non-RPC path then it returns a plain 404 response',
      () async {
        final response = await _send(
          baseUri.resolve('/missing'),
          method: 'POST',
        );

        expect(response.statusCode, HttpStatus.notFound);
        expect(response.body, 'Not Found');
      },
    );

    test(
      'When requesting a generated REST path then it returns the raw JSON response',
      () async {
        final response = await _send(
          baseUri.resolve('/meta/users/7?include=compact'),
          method: 'GET',
          headers: const {'x-trace-id': 'trace-rest'},
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(
          response.headers.value('content-type'),
          contains('application/json'),
        );
        expect(jsonDecode(response.body), {
          'httpMethod': 'GET',
          'path': '/meta/users/7',
          'traceId': 'trace-rest',
          'id': '7',
          'include': 'compact',
        });
      },
    );

    test(
      'When using the wrong method for a REST path then it returns method not allowed',
      () async {
        final response = await _send(
          baseUri.resolve('/meta/users/7'),
          method: 'POST',
        );

        expect(response.statusCode, HttpStatus.methodNotAllowed);
        expect(response.headers.value('allow'), 'GET');
        expect(jsonDecode(response.body), {
          'error': {
            'code': 'BAD_REQUEST',
            'message': 'REST endpoint only accepts GET requests.',
          },
        });
      },
    );

    test(
      'When requesting /openapi.json then it returns the configured OpenAPI document',
      () async {
        final response = await _send(
          baseUri.resolve('/openapi.json'),
          method: 'GET',
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(jsonDecode(response.body), {
          'openapi': '3.0.3',
          'info': {'title': 'Meta API', 'version': '1.0.0'},
          'paths': {},
          'components': {'schemas': {}},
        });
      },
    );

    test(
      'When requesting /docs then it returns the configured HTML docs page',
      () async {
        final response = await _send(baseUri.resolve('/docs'), method: 'GET');

        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.value('content-type'), contains('text/html'));
        expect(response.body, '<html><body>Meta Docs</body></html>');
      },
    );
  });

  group('Given a running RpcHttpApp with docs basic auth', () {
    late HttpServer server;
    late Uri baseUri;

    setUp(() async {
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        openApiDocument: const {
          'openapi': '3.0.3',
          'info': {'title': 'Secure API', 'version': '1.0.0'},
          'paths': {},
          'components': {'schemas': {}},
        },
        docsHtml: '<html><body>Secure Docs</body></html>',
        docsBasicAuth: const RpcHttpBasicAuth(
          username: 'docs',
          password: 'secret',
          realm: 'Docs',
        ),
      );

      server = await app.listen(
        0,
        hostname: InternetAddress.loopbackIPv4.address,
      );
      baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'When requesting docs without credentials then it returns unauthorized',
      () async {
        final response = await _send(baseUri.resolve('/docs'), method: 'GET');

        expect(response.statusCode, HttpStatus.unauthorized);
        expect(
          response.headers.value('www-authenticate'),
          'Basic realm="Docs"',
        );
        expect(response.body, 'Unauthorized');
      },
    );

    test(
      'When requesting the OpenAPI document with invalid credentials then it returns unauthorized',
      () async {
        final response = await _send(
          baseUri.resolve('/openapi.json'),
          method: 'GET',
          headers: {'authorization': _basicAuthHeader('docs', 'wrong')},
        );

        expect(response.statusCode, HttpStatus.unauthorized);
        expect(
          response.headers.value('www-authenticate'),
          'Basic realm="Docs"',
        );
      },
    );

    test(
      'When requesting docs and OpenAPI with valid credentials then it serves both resources',
      () async {
        final docsResponse = await _send(
          baseUri.resolve('/docs'),
          method: 'GET',
          headers: {'authorization': _basicAuthHeader('docs', 'secret')},
        );
        final openApiResponse = await _send(
          baseUri.resolve('/openapi.json'),
          method: 'GET',
          headers: {'authorization': _basicAuthHeader('docs', 'secret')},
        );

        expect(docsResponse.statusCode, HttpStatus.ok);
        expect(docsResponse.body, '<html><body>Secure Docs</body></html>');
        expect(openApiResponse.statusCode, HttpStatus.ok);
        expect(jsonDecode(openApiResponse.body), {
          'openapi': '3.0.3',
          'info': {'title': 'Secure API', 'version': '1.0.0'},
          'paths': {},
          'components': {'schemas': {}},
        });
      },
    );
  });

  group('Given a running RpcHttpApp with middleware', () {
    late HttpServer server;
    late Uri baseUri;

    setUp(() async {
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry([
          RpcProcedure<JsonObject, JsonObject>(
            method: 'meta.echo',
            decodeInput: (rawInput) =>
                expectJsonObject(rawInput, context: 'meta.echo input'),
            encodeOutput: (output) => output,
            handler: (context, input) async {
              return {'traceId': context.headers['x-trace-id'], 'input': input};
            },
          ),
        ]),
        middleware: [
          (next) => (request) async {
            final response = await next(
              RpcHttpRequest(
                method: request.method,
                path: request.path,
                headers: {...request.headers, 'x-trace-id': 'middleware-trace'},
                queryParameters: request.queryParameters,
                body: request.body,
              ),
            );
            return RpcHttpResponse(
              statusCode: response.statusCode,
              headers: {...response.headers, 'x-middleware': 'enabled'},
              body: response.body,
            );
          },
        ],
      );

      server = await app.listen(
        0,
        hostname: InternetAddress.loopbackIPv4.address,
      );
      baseUri = Uri.parse('http://${server.address.address}:${server.port}');
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'When POSTing through the app then middleware can wrap the request and response',
      () async {
        final response = await _send(
          baseUri.resolve('/rpc'),
          method: 'POST',
          body: jsonEncode({
            'method': 'meta.echo',
            'input': {'id': '1'},
          }),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.value('x-middleware'), 'enabled');
        expect(jsonDecode(response.body), {
          'data': {
            'traceId': 'middleware-trace',
            'input': {'id': '1'},
          },
        });
      },
    );
  });
}

Future<_HttpResponseData> _send(
  Uri uri, {
  required String method,
  Map<String, String> headers = const {},
  String body = '',
}) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, uri);
    headers.forEach(request.headers.set);
    if (body.isNotEmpty) {
      request.headers.set('content-type', 'application/json; charset=utf-8');
      request.write(body);
    }

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    return _HttpResponseData(
      statusCode: response.statusCode,
      headers: response.headers,
      body: responseBody,
    );
  } finally {
    client.close(force: true);
  }
}

final class _HttpResponseData {
  const _HttpResponseData({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}

String _basicAuthHeader(String username, String password) {
  final credentials = base64Encode(utf8.encode('$username:$password'));
  return 'Basic $credentials';
}

import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('createRpcHttpHandler', () {
    late RpcHttpHandler handler;
    late RpcProcedureRegistry registry;
    late RestRouteRegistry restRoutes;

    setUp(() {
      registry = RpcProcedureRegistry([
        RpcProcedure<JsonObject, JsonObject>(
          method: 'user.getById',
          decodeInput: (rawInput) =>
              expectJsonObject(rawInput, context: 'get user input'),
          encodeOutput: (output) => output,
          handler: (_, input) async {
            return {'id': input['id'], 'name': 'Ada Lovelace'};
          },
        ),
      ]);

      restRoutes = RestRouteRegistry([
        RestRoute(
          method: 'GET',
          path: '/users/:id',
          handler: (context, request, pathParameters) async {
            final id = decodeRestScalarParameter<String>(
              rawValue: pathParameters['id'],
              source: 'path parameter',
              name: 'id',
              route: 'GET /users/:id',
            );
            final include = decodeRestScalarParameter<String?>(
              rawValue: request.queryParameters['include'],
              source: 'query parameter',
              name: 'include',
              route: 'GET /users/:id',
            );
            final tenantId = decodeRestScalarParameter<String?>(
              rawValue: lookupRestHeader(request.headers, 'x-tenant-id'),
              source: 'header',
              name: 'x-tenant-id',
              route: 'GET /users/:id',
            );
            return {
              'id': id,
              'name': include == 'compact' ? 'Ada' : 'Ada Lovelace',
              'method': context.httpMethod,
              if (tenantId != null) 'tenantId': tenantId,
            };
          },
        ),
        RestRoute(
          method: 'POST',
          path: '/users',
          handler: (_, request, __) async {
            final body = decodeRestBody<JsonObject>(
              rawBody: request.body,
              route: 'POST /users',
              parameterName: 'body',
              decode: (rawJson) =>
                  expectJsonObject(rawJson, context: 'POST /users body'),
            );
            return {'created': body};
          },
        ),
      ]);

      handler = createRpcHttpHandler(
        procedures: registry,
        restRoutes: restRoutes,
        openApiDocument: const {
          'openapi': '3.0.3',
          'info': {'title': 'Test API', 'version': '1.0.0'},
          'paths': {},
          'components': {'schemas': {}},
        },
        docsHtml: '<html><body>Docs</body></html>',
      );
    });

    test('returns a data envelope for valid requests', () async {
      final response = await handler(
        RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          body: jsonEncode({
            'method': 'user.getById',
            'input': {'id': '123'},
          }),
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), {
        'data': {'id': '123', 'name': 'Ada Lovelace'},
      });
    });

    test('returns an rpc error envelope for unknown methods', () async {
      final response = await handler(
        RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          body: jsonEncode({
            'method': 'user.missing',
            'input': {'id': '123'},
          }),
        ),
      );

      expect(response.statusCode, HttpStatus.notFound);
      expect(jsonDecode(response.body), {
        'error': {
          'code': 'NOT_FOUND',
          'message': 'No RPC procedure registered for "user.missing".',
        },
      });
    });

    test('returns bad request for invalid json', () async {
      final response = await handler(
        const RpcHttpRequest(method: 'POST', path: '/rpc', body: '{'),
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(jsonDecode(response.body), {
        'error': {
          'code': 'BAD_REQUEST',
          'message': 'RPC request body must be valid JSON.',
        },
      });
    });

    test('returns method not allowed for non-POST RPC requests', () async {
      final response = await handler(
        const RpcHttpRequest(method: 'GET', path: '/rpc'),
      );

      expect(response.statusCode, HttpStatus.methodNotAllowed);
      expect(response.headers['allow'], 'POST');
    });

    test('returns a raw JSON response for valid REST requests', () async {
      final response = await handler(
        const RpcHttpRequest(
          method: 'GET',
          path: '/users/123',
          queryParameters: {'include': 'compact'},
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), {
        'id': '123',
        'name': 'Ada',
        'method': 'GET',
      });
    });

    test('reads REST headers case-insensitively', () async {
      final response = await handler(
        const RpcHttpRequest(
          method: 'GET',
          path: '/users/123',
          headers: {'X-Tenant-Id': 'tenant-1'},
        ),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), {
        'id': '123',
        'name': 'Ada Lovelace',
        'method': 'GET',
        'tenantId': 'tenant-1',
      });
    });

    test(
      'returns method not allowed for REST paths with a wrong method',
      () async {
        final response = await handler(
          const RpcHttpRequest(method: 'POST', path: '/users/123'),
        );

        expect(response.statusCode, HttpStatus.methodNotAllowed);
        expect(response.headers['allow'], 'GET');
        expect(jsonDecode(response.body), {
          'error': {
            'code': 'BAD_REQUEST',
            'message': 'REST endpoint only accepts GET requests.',
          },
        });
      },
    );

    test('returns bad request for invalid REST JSON bodies', () async {
      final response = await handler(
        const RpcHttpRequest(method: 'POST', path: '/users', body: '{'),
      );

      expect(response.statusCode, HttpStatus.badRequest);
      expect(jsonDecode(response.body), {
        'error': {
          'code': 'BAD_REQUEST',
          'message': 'REST request body for "POST /users" must be valid JSON.',
        },
      });
    });

    test('returns the generated OpenAPI document', () async {
      final response = await handler(
        const RpcHttpRequest(method: 'GET', path: '/openapi.json'),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(jsonDecode(response.body), {
        'openapi': '3.0.3',
        'info': {'title': 'Test API', 'version': '1.0.0'},
        'paths': {},
        'components': {'schemas': {}},
      });
    });

    test('returns the configured docs HTML', () async {
      final response = await handler(
        const RpcHttpRequest(method: 'GET', path: '/docs'),
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.body, '<html><body>Docs</body></html>');
    });

    test(
      'applies middleware in declaration order and allows request and response wrapping',
      () async {
        final trace = <String>[];
        final middlewareHandler = createRpcHttpHandler(
          procedures: registry,
          restRoutes: restRoutes,
          middleware: [
            (next) => (request) async {
              trace.add('first-before');
              final response = await next(
                RpcHttpRequest(
                  method: request.method,
                  path: request.path,
                  headers: {
                    ...request.headers,
                    'x-tenant-id': 'tenant-from-middleware',
                  },
                  queryParameters: request.queryParameters,
                  body: request.body,
                ),
              );
              trace.add('first-after');
              return RpcHttpResponse(
                statusCode: response.statusCode,
                headers: {...response.headers, 'x-middleware': 'wrapped'},
                body: response.body,
              );
            },
            (next) => (request) async {
              trace.add('second-before');
              final response = await next(request);
              trace.add('second-after');
              return response;
            },
          ],
        );

        final response = await middlewareHandler(
          const RpcHttpRequest(method: 'GET', path: '/users/123'),
        );

        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers['x-middleware'], 'wrapped');
        expect(jsonDecode(response.body), {
          'id': '123',
          'name': 'Ada Lovelace',
          'method': 'GET',
          'tenantId': 'tenant-from-middleware',
        });
        expect(trace, [
          'first-before',
          'second-before',
          'second-after',
          'first-after',
        ]);
      },
    );

    test('allows middleware to short-circuit requests', () async {
      final middlewareHandler = createRpcHttpHandler(
        procedures: registry,
        restRoutes: restRoutes,
        middleware: [
          (next) => (request) async {
            if (request.path == '/rpc') {
              return const RpcHttpResponse(
                statusCode: HttpStatus.forbidden,
                headers: {'content-type': 'text/plain; charset=utf-8'},
                body: 'Blocked by middleware',
              );
            }

            return next(request);
          },
        ],
      );

      final response = await middlewareHandler(
        RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          body: jsonEncode({
            'method': 'user.getById',
            'input': {'id': '123'},
          }),
        ),
      );

      expect(response.statusCode, HttpStatus.forbidden);
      expect(response.body, 'Blocked by middleware');
    });
  });
}

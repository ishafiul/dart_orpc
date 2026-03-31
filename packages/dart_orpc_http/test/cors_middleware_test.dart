import 'dart:io';

import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('CORS Middleware', () {
    final next = (RpcHttpRequest request) async {
      return const RpcHttpResponse(
        statusCode: HttpStatus.ok,
        headers: {'content-type': 'text/plain; charset=utf-8'},
        body: 'OK',
      );
    };

    test('adds default CORS headers to regular requests', () async {
      final middleware = createCorsMiddleware();
      final handler = middleware(next);

      final response = await handler(
        const RpcHttpRequest(method: 'GET', path: '/'),
      );

      expect(response.headers['access-control-allow-origin'], '*');
      expect(
        response.headers['access-control-allow-methods'],
        contains('GET, POST'),
      );
    });

    test('handles preflight OPTIONS requests', () async {
      final middleware = createCorsMiddleware();
      final handler = middleware(next);

      final response = await handler(
        const RpcHttpRequest(method: 'OPTIONS', path: '/'),
      );

      expect(response.statusCode, HttpStatus.noContent);
      expect(response.headers['access-control-allow-origin'], '*');
      expect(
        response.headers['access-control-allow-methods'],
        contains('OPTIONS'),
      );
      expect(response.body, isEmpty);
    });

    test('supports custom allowOrigin', () async {
      final middleware = createCorsMiddleware(
        const CorsOptions(allowOrigin: 'https://example.com'),
      );
      final handler = middleware(next);

      final response = await handler(
        const RpcHttpRequest(method: 'GET', path: '/'),
      );

      expect(
        response.headers['access-control-allow-origin'],
        'https://example.com',
      );
    });

    test('supports allowCredentials with specific origin', () async {
      final middleware = createCorsMiddleware(
        const CorsOptions(allowCredentials: true),
      );
      final handler = middleware(next);

      final response = await handler(
        const RpcHttpRequest(
          method: 'GET',
          path: '/',
          headers: {'origin': 'https://example.com'},
        ),
      );

      expect(
        response.headers['access-control-allow-origin'],
        'https://example.com',
      );
      expect(response.headers['access-control-allow-credentials'], 'true');
    });

    test(
      'does not add allow-credentials if origin is missing even if requested',
      () async {
        final middleware = createCorsMiddleware(
          const CorsOptions(allowCredentials: true),
        );
        final handler = middleware(next);

        final response = await handler(
          const RpcHttpRequest(method: 'GET', path: '/'),
        );

        expect(
          response.headers.containsKey('access-control-allow-origin'),
          isFalse,
        );
        expect(
          response.headers.containsKey('access-control-allow-credentials'),
          isFalse,
        );
      },
    );

    test('supports custom allowMethods and allowHeaders', () async {
      final middleware = createCorsMiddleware(
        const CorsOptions(
          allowMethods: ['GET', 'POST'],
          allowHeaders: ['X-Custom-Header'],
        ),
      );
      final handler = middleware(next);

      final response = await handler(
        const RpcHttpRequest(method: 'OPTIONS', path: '/'),
      );

      expect(response.headers['access-control-allow-methods'], 'GET, POST');
      expect(
        response.headers['access-control-allow-headers'],
        'X-Custom-Header',
      );
    });

    test('supports exposeHeaders and maxAge', () async {
      final middleware = createCorsMiddleware(
        const CorsOptions(exposeHeaders: ['X-Exposed'], maxAge: 3600),
      );
      final handler = middleware(next);

      final response = await handler(
        const RpcHttpRequest(method: 'GET', path: '/'),
      );

      expect(response.headers['access-control-expose-headers'], 'X-Exposed');
      expect(response.headers['access-control-max-age'], '3600');
    });
  });
}

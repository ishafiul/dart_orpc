import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('CORS Middleware', () {
    test('preserves streamed responses and their buffering policy', () async {
      for (final flushEachChunk in [true, false]) {
        final handler = createCorsMiddleware()(
          (_) async => RpcHttpResponse.streaming(
            statusCode: HttpStatus.accepted,
            headers: const {'content-type': 'text/event-stream'},
            body: Stream.value(utf8.encode('data: ready\n\n')),
            flushEachChunk: flushEachChunk,
          ),
        );
        final response = await handler(
          const RpcHttpRequest(method: 'GET', path: '/events'),
        );
        expect(response.statusCode, HttpStatus.accepted);
        expect(response.isStreaming, isTrue);
        expect(response.headers['content-type'], 'text/event-stream');
        expect(response.headers['access-control-allow-origin'], '*');
        final content = response.content as RpcStreamingHttpBody;
        expect(content.flushEachChunk, flushEachChunk);
        expect(await utf8.decodeStream(content.chunks), 'data: ready\n\n');
      }
    });

    test(
      'credential origins remain isolated across cached preflight headers',
      () async {
        final handler = createCorsMiddleware(
          const CorsOptions(
            allowCredentials: true,
            allowedOrigins: [
              'https://example.com',
              'https://one.example',
              'https://two.example',
            ],
          ),
        )((_) async => const RpcHttpResponse(statusCode: HttpStatus.ok));
        for (final origin in [
          'https://one.example',
          'https://two.example',
          null,
        ]) {
          final response = await handler(
            RpcHttpRequest(
              method: 'OPTIONS',
              path: '/',
              headers: {if (origin != null) 'Origin': origin},
            ),
          );
          expect(response.headers['access-control-allow-origin'], origin);
          expect(
            response.headers['access-control-allow-credentials'],
            origin == null ? null : 'true',
          );
          expect(
            response.headers['access-control-allow-methods'],
            contains('GET'),
          );
        }
      },
    );

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
      expect(response.body, isNull);
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
        const CorsOptions(
          allowCredentials: true,
          allowedOrigins: [
            'https://example.com',
            'https://one.example',
            'https://two.example',
          ],
        ),
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
          const CorsOptions(
            allowCredentials: true,
            allowedOrigins: [
              'https://example.com',
              'https://one.example',
              'https://two.example',
            ],
          ),
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

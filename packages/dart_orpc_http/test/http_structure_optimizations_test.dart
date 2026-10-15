import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  RestUnaryRoute route(String method, String path) => RestUnaryRoute(
    method: method,
    path: path,
    handler: (_, _, parameters) => parameters,
  );

  test(
    'prepared routing reuses match and parameters through request copies',
    () async {
      final registry = RestRouteRegistry([route('GET', '/items/:id')]);
      final prepared = registry.prepareRequest(
        const RpcHttpRequest(method: 'GET', path: '/items/one'),
      );
      final match = registry.matchRequest(prepared)!;
      final copy = prepared.copyWith(body: '{}', headers: {'x-test': 'yes'});
      expect(registry.prepareRequest(prepared), same(prepared));
      expect(registry.matchRequest(copy), same(match));
      expect(
        registry.matchRequest(copy)?.pathParameters,
        same(match.pathParameters),
      );
      final handler = createRpcHttpHandler(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: registry,
      );
      expect(jsonDecode((await handler(copy)).body as String), {'id': 'one'});
      expect(
        registry
            .matchRequest(prepared.copyWith(path: '/items/two'))
            ?.pathParameters,
        {'id': 'two'},
      );
      expect(registry.matchRequest(prepared.copyWith(method: 'POST')), isNull);
      final other = RestRouteRegistry([route('GET', '/items/:other')]);
      expect(other.matchRequest(prepared)?.pathParameters, {'other': 'one'});
    },
  );

  test(
    'cached misses invalidate on rewrites and HEAD honors explicit route',
    () async {
      final registry = RestRouteRegistry([
        route('GET', '/items/:id'),
        route('HEAD', '/:kind/one'),
      ]);
      final miss = registry.prepareRequest(
        const RpcHttpRequest(method: 'POST', path: '/items/one'),
      );
      expect(registry.matchRequest(miss), isNull);
      final head = miss.copyWith(method: 'HEAD');
      expect(registry.matchRequest(head)?.route.path, '/:kind/one');
      final fallback = head.copyWith(path: '/items/two');
      expect(registry.matchRequest(fallback)?.route.path, '/items/:id');
      final handler = createRpcHttpHandler(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: registry,
        middleware: [
          (next) =>
              (request) =>
                  next(request.copyWith(method: 'GET', path: '/items/two')),
        ],
      );
      expect(jsonDecode((await handler(miss)).body as String), {'id': 'two'});
      final withoutRewrite = createRpcHttpHandler(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: registry,
      );
      final rejected = await withoutRewrite(miss);
      expect(rejected.statusCode, 405);
      expect(rejected.headers['allow'], 'GET, HEAD');
    },
  );

  test(
    'method-aware trie agrees with registration-ordered reference matcher',
    () {
      final routes = [
        for (final method in ['GET', 'POST', 'HEAD', 'CUSTOM'])
          for (final first in ['a', 'b', ':first'])
            for (final second in ['x', 'y', ':second'])
              for (final third in ['last', ':third'])
                route(method, '/$first/$second/$third'),
        route('GET', '/'),
      ]..shuffle(Random(73));
      final registry = RestRouteRegistry(routes);
      for (final method in ['GET', 'POST', 'HEAD', 'CUSTOM', 'MISSING']) {
        for (final first in ['a', 'b', 'other']) {
          for (final second in ['x', 'y', 'other']) {
            for (final third in ['last', 'other']) {
              final parts = [first, second, third];
              final path = '//${parts.join('//')}/';
              final matching = routes
                  .where((route) => _matches(route.path, parts))
                  .toList();
              final expected = matching
                  .where((route) => route.method == method)
                  .firstOrNull;
              final actual = registry.match(method: method, path: path);
              expect(actual?.route, same(expected), reason: '$method $path');
              if (expected != null) {
                final segments = expected.path.substring(1).split('/');
                expect(actual!.pathParameters, {
                  for (var index = 0; index < segments.length; index++)
                    if (segments[index].startsWith(':'))
                      segments[index].substring(1): parts[index],
                });
              }
              expect(
                registry.allowedMethodsFor(path),
                matching.map((route) => route.method).toSet().toList()..sort(),
              );
            }
          }
        }
      }
    },
  );

  test(
    'CORS snapshots static collections and preserves dynamic origin policy',
    () async {
      final origins = _CountedStrings(['https://one.example']);
      final methods = _CountedStrings(['get', 'POST']);
      final headers = _CountedStrings(['X-Test']);
      final exposed = _CountedStrings(['X-Result']);
      var dynamicAllowed = false;
      final handler =
          createCorsMiddleware(
            CorsOptions(
              allowedOrigins: origins,
              allowMethods: methods,
              allowHeaders: headers,
              exposeHeaders: exposed,
              allowCredentials: true,
              maxAge: 60,
              allowOriginPredicate: (origin) =>
                  dynamicAllowed && origin == 'https://dynamic.example',
            ),
          )(
            (_) async => const RpcHttpResponse(
              statusCode: 200,
              headers: {'Vary': 'Accept-Encoding, origin'},
            ),
          );
      final reads = [
        origins.reads,
        methods.reads,
        headers.reads,
        exposed.reads,
      ];
      origins.values[0] = 'https://changed.example';
      methods.values[0] = 'DELETE';
      headers.values[0] = 'X-Changed';
      exposed.values[0] = 'X-Changed';
      for (var index = 0; index < 3; index++) {
        final response = await handler(
          const RpcHttpRequest(
            method: 'OPTIONS',
            path: '/',
            headers: {
              'origin': 'https://one.example',
              'access-control-request-method': 'GeT',
              'access-control-request-headers': 'x-TEST',
            },
          ),
        );
        expect(response.statusCode, 204);
        expect(
          response.headers['access-control-allow-origin'],
          'https://one.example',
        );
        expect(response.headers['access-control-allow-methods'], 'get, POST');
        expect(response.headers['access-control-allow-headers'], 'X-Test');
        expect(response.headers['access-control-expose-headers'], 'X-Result');
        expect(response.headers['access-control-max-age'], '60');
      }
      expect([
        origins.reads,
        methods.reads,
        headers.reads,
        exposed.reads,
      ], reads);
      Future<RpcHttpResponse> dynamicRequest() => handler(
        const RpcHttpRequest(
          method: 'GET',
          path: '/',
          headers: {'origin': 'https://dynamic.example'},
        ),
      );
      expect(
        (await dynamicRequest()).headers['access-control-allow-origin'],
        isNull,
      );
      dynamicAllowed = true;
      final response = await dynamicRequest();
      expect(
        response.headers['access-control-allow-origin'],
        'https://dynamic.example',
      );
      expect(response.headers['vary'], 'Accept-Encoding, origin');
    },
  );

  test(
    'histogram retains cumulative boundaries and snapshots do not mutate bins',
    () {
      final metrics = RpcHttpMetricsCollector();
      const boundaries = [
        5000,
        10000,
        25000,
        50000,
        100000,
        250000,
        500000,
        1000000,
        2500000,
        5000000,
        10000000,
      ];
      final observations = [
        0,
        for (final boundary in boundaries) ...[
          boundary - 1,
          boundary,
          boundary + 1,
        ],
        20000000,
      ];
      for (final elapsed in observations) {
        metrics.begin();
        metrics.complete(
          RpcHttpCompletion(
            request: const RpcHttpRequest(method: 'GET', path: '/test'),
            route: '/test',
            statusCode: 200,
            elapsed: Duration(microseconds: elapsed),
            receivedBytes: 1,
            sentBytes: 2,
            streaming: false,
            disconnected: false,
          ),
        );
      }
      Map histogram() =>
          ((metrics.snapshot()['routes'] as Map)['GET /test']
                  as Map)['duration_seconds_buckets']
              as Map;
      final first = histogram();
      for (final boundary in boundaries) {
        expect(
          first['${boundary / Duration.microsecondsPerSecond}'],
          observations.where((elapsed) => elapsed <= boundary).length,
        );
      }
      expect(first['+Inf'], observations.length);
      expect(histogram(), first);
      first['+Inf'] = -1;
      expect(histogram()['+Inf'], observations.length);
      expect(metrics.activeRequests, 0);
    },
  );

  test(
    'repeated rate-limit hits preserve sliding expiry and identity capacity',
    () {
      var now = DateTime.utc(2026);
      final limiter = RpcHttpRateLimiter(
        const RpcHttpRateLimitOptions(
          maxRequests: 3,
          maxKeys: 2,
          window: Duration(seconds: 10),
        ),
        clock: () => now,
      );
      const one = RpcHttpRequest(
        method: 'GET',
        path: '/',
        remoteAddress: 'one',
      );
      const two = RpcHttpRequest(
        method: 'GET',
        path: '/',
        remoteAddress: 'two',
      );
      const three = RpcHttpRequest(
        method: 'GET',
        path: '/',
        remoteAddress: 'three',
      );
      expect(limiter.check(one), isNull);
      now = now.add(const Duration(seconds: 2));
      expect(limiter.check(two), isNull);
      expect(limiter.check(one), isNull);
      expect(limiter.check(one), isNull);
      expect(limiter.check(one), const Duration(seconds: 8));
      expect(limiter.check(three), isNotNull);
      now = now.add(const Duration(seconds: 8));
      expect(limiter.check(three), const Duration(seconds: 2));
      expect(limiter.check(one), isNull);
      expect(limiter.check(one), const Duration(seconds: 2));
      now = now.add(const Duration(seconds: 2));
      expect(limiter.check(three), isNull);
      expect(limiter.check(two), const Duration(seconds: 8));
      now = now.add(const Duration(seconds: 2));
      expect(limiter.check(one), isNull);
      expect(limiter.check(three), isNull);
    },
  );
}

bool _matches(String template, List<String> parts) {
  final segments = template.substring(1).split('/');
  if (segments.length != parts.length) return false;
  for (var index = 0; index < segments.length; index++) {
    if (!segments[index].startsWith(':') && segments[index] != parts[index])
      return false;
  }
  return true;
}

final class _CountedStrings extends ListBase<String> {
  _CountedStrings(this.values);
  final List<String> values;
  int reads = 0;
  @override
  int get length => values.length;
  @override
  set length(int value) => values.length = value;
  @override
  String operator [](int index) {
    reads++;
    return values[index];
  }

  @override
  void operator []=(int index, String value) => values[index] = value;
}

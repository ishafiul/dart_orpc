import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  test(
    'metrics, completion and dispatch share match after body buffering',
    () async {
      final completed = Completer<RpcHttpCompletion>();
      late RestRouteRegistry registry;
      RestRouteMatch? observed;
      registry = RestRouteRegistry([
        RestUnaryRoute(
          method: 'POST',
          path: '/items/:id',
          handler: (_, request, parameters) {
            expect(registry.matchRequest(request), same(observed));
            expect(parameters, same(observed!.pathParameters));
            expect(request.body, '{"value":true}');
            return parameters;
          },
        ),
      ]);
      final origins = ['https://one.example'];
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        restRoutes: registry,
        metrics: const RpcHttpMetricsOptions(),
        serverOptions: RpcHttpServerOptions(
          onComplete: completed.complete,
          cors: CorsOptions(allowedOrigins: origins, allowCredentials: true),
        ),
        middleware: [
          (next) => (request) {
            observed = registry.matchRequest(request);
            // Both metric-enabled and completion-enabled requests were prepared
            // before the body copy. A fresh lookup would allocate another match.
            expect(registry.matchRequest(request), same(observed));
            return next(
              request.copyWith(headers: {...request.headers, 'x-copy': 'yes'}),
            );
          },
        ],
      );
      origins[0] = 'https://changed.example';
      final server = await app.listen(0, hostname: '127.0.0.1');
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}/items/one'),
      );
      request.headers.set('origin', 'https://one.example');
      request.write('{"value":true}');
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(
        response.headers.value('access-control-allow-origin'),
        'https://one.example',
      );
      expect(jsonDecode(await utf8.decodeStream(response)), {'id': 'one'});
      final event = await completed.future;
      expect(event.route, '/items/:id');
      expect(registry.matchRequest(event.request), same(observed));
    },
  );

  test(
    'HEAD completion label uses explicit HEAD route before GET fallback',
    () async {
      final events = StreamController<RpcHttpCompletion>();
      addTearDown(events.close);
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        serverOptions: RpcHttpServerOptions(onComplete: events.add),
        restRoutes: RestRouteRegistry([
          RestUnaryRoute(
            method: 'GET',
            path: '/items/:id',
            handler: (_, _, parameters) => parameters,
          ),
          RestUnaryRoute(
            method: 'HEAD',
            path: '/:kind/one',
            handler: (_, _, parameters) => parameters,
          ),
        ]),
      );
      final server = await app.listen(0, hostname: '127.0.0.1');
      addTearDown(() => server.close(force: true));
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final observed = events.stream.take(2).toList();
      for (final path in ['/items/one', '/items/two']) {
        final request = await client.openUrl(
          'HEAD',
          Uri.parse('http://127.0.0.1:${server.port}$path'),
        );
        final response = await request.close();
        expect(response.statusCode, 200);
        expect(await response.expand((bytes) => bytes).toList(), isEmpty);
      }
      expect((await observed).map((event) => event.route), [
        '/:kind/one',
        '/items/:id',
      ]);
    },
  );
}

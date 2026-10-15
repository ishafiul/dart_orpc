import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  group('REST route lookup', () {
    RestUnaryRoute route(String method, String path) => RestUnaryRoute(
      method: method,
      path: path,
      handler: (_, _, parameters) => parameters,
    );

    test('literal fast path preserves root, case and slash semantics', () {
      final root = route('GET', '/');
      final users = route('GET', '/users/list');
      final registry = RestRouteRegistry([root, users]);

      for (final path in ['', '/', '//']) {
        expect(registry.match(method: 'get', path: path)?.route, same(root));
      }
      for (final path in [
        'users/list',
        '/users/list/',
        '/users/list//',
        '//users///list//',
      ]) {
        final match = registry.match(method: 'get', path: path);
        expect(match?.route, same(users));
        expect(match?.pathParameters, isEmpty);
        expect(registry.allowedMethodsFor(path), ['GET']);
      }
      expect(registry.match(method: 'GET', path: '/Users/list'), isNull);
      expect(registry.match(method: 'POST', path: '/users/list'), isNull);
      expect(registry.allowedMethodsFor('/missing'), isEmpty);
    });

    test('earlier registrations win across literal and parameter branches', () {
      final literal = route('GET', '/users/me');
      final parameter = route('GET', '/users/:id');

      for (final routes in [
        [literal, parameter],
        [parameter, literal],
      ]) {
        final registry = RestRouteRegistry(routes);
        final match = registry.match(method: 'GET', path: '/users/me');
        expect(match?.route, same(routes.first));
        expect(
          match?.pathParameters,
          routes.first == parameter ? {'id': 'me'} : isEmpty,
        );
      }

      final earlier = route('GET', '/:group/list');
      final later = route('GET', '/users/:id');
      final registry = RestRouteRegistry([earlier, later]);
      final match = registry.match(method: 'GET', path: '/users/list');
      expect(match?.route, same(earlier));
      expect(match?.pathParameters, {'group': 'users'});
      expect(
        () => match!.pathParameters['group'] = 'changed',
        throwsUnsupportedError,
      );
    });

    test(
      'method misses combine literal and parameter routes into sorted Allow',
      () async {
        final registry = RestRouteRegistry([
          route('POST', '/users/me'),
          route('GET', '/users/:id'),
          route('DELETE', '/:group/me'),
        ]);
        expect(registry.allowedMethodsFor('//users//me/'), [
          'DELETE',
          'GET',
          'POST',
        ]);
        final response = await createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          restRoutes: registry,
        )(const RpcHttpRequest(method: 'PUT', path: '//users//me/'));
        expect(response.statusCode, HttpStatus.methodNotAllowed);
        expect(response.headers['allow'], 'DELETE, GET, HEAD, POST');
        expect(
          registry.match(method: 'GET', path: '/users/me')?.pathParameters,
          {'id': 'me'},
        );
      },
    );

    test('duplicate canonical route shapes still fail at startup', () {
      for (final paths in [
        ['/users/:id', '//users/:name/'],
        ['/users/list', 'users//list/'],
      ]) {
        expect(
          () => RestRouteRegistry(paths.map((path) => route('GET', path))),
          throwsStateError,
        );
      }
    });
  });

  test(
    'header lookup accepts normalized, mixed-case, missing and empty values',
    () {
      expect(
        lookupRestHeader({'authorization': 'token'}, 'Authorization'),
        'token',
      );
      expect(lookupRestHeader({'X-Trace-ID': 'one'}, 'x-trace-id'), 'one');
      expect(lookupRestHeader({'origin': ''}, 'Origin'), '');
      expect(lookupRestHeader({}, 'origin'), isNull);
    },
  );

  test('handler context snapshots mutable request headers', () async {
    final headers = {'x-trace-id': 'original'};
    final entered = Completer<RpcContext>();
    final release = Completer<void>();
    final handler = createRpcHttpHandler(
      procedures: RpcProcedureRegistry(const []),
      restRoutes: RestRouteRegistry([
        RestUnaryRoute(
          method: 'GET',
          path: '/context',
          handler: (context, _, _) async {
            entered.complete(context);
            await release.future;
            return context.headers;
          },
        ),
      ]),
    );
    final response = handler(
      RpcHttpRequest(method: 'GET', path: '/context', headers: headers),
    );
    final context = await entered.future;
    headers['x-trace-id'] = 'changed';
    expect(context.headers['x-trace-id'], 'original');
    expect(
      () => context.headers['x-trace-id'] = 'mutated',
      throwsUnsupportedError,
    );
    release.complete();
    expect(jsonDecode((await response).body! as String), {
      'x-trace-id': 'original',
    });
  });

  group('JSON output', () {
    for (final encodeBytes in [false, true]) {
      test(
        'RPC and REST preserve Unicode and envelopes with byte encoding $encodeBytes',
        () async {
          const output = {
            'message': 'héllo বাংলা',
            'items': [1, true, null],
          };
          final handler = createRpcHttpHandler(
            procedures: RpcProcedureRegistry([
              RpcUnaryProcedure<Null, Map<String, Object?>>(
                method: 'test.echo',
                metadata: const ProcedureMetadata(
                  rpcMethod: 'test.echo',
                  controllerNamespace: 'test',
                  methodName: 'echo',
                  outputTypeCode: 'Map<String, Object?>',
                ),
                decodeInput: (_) => null,
                encodeOutput: (value) => value,
                handler: (_, _) => output,
              ),
            ]),
            restRoutes: RestRouteRegistry([
              RestUnaryRoute(
                method: 'GET',
                path: '/echo',
                handler: (_, _, _) => output,
              ),
              RestUnaryRoute(
                method: 'GET',
                path: '/bytes',
                handler: (_, _, _) => _JsonBytes(output),
              ),
            ]),
            encodeJsonToBytes: encodeBytes,
          );
          final rpc = await handler(
            const RpcHttpRequest(
              method: 'POST',
              path: '/rpc',
              body: '{"method":"test.echo"}',
            ),
          );
          final rest = await handler(
            const RpcHttpRequest(method: 'GET', path: '/echo'),
          );
          final bytes = await handler(
            const RpcHttpRequest(method: 'GET', path: '/bytes'),
          );
          expect(rpc.body, encodeBytes ? isA<List<int>>() : isA<String>());
          expect(rest.body, encodeBytes ? isA<List<int>>() : isA<String>());
          expect(jsonDecode(_bodyText(rpc)), {'data': output});
          expect(jsonDecode(_bodyText(rest)), output);
          expect(bytes.body, isA<List<int>>());
          expect(jsonDecode(_bodyText(bytes)), output);
        },
      );
    }

    test('OpenAPI serializes once and serves startup snapshot', () async {
      final counted = _CountedJson();
      final document = <String, Object?>{'info': counted};
      final handler = createRpcHttpHandler(
        procedures: RpcProcedureRegistry(const []),
        openApiDocument: document,
      );
      document['extra'] = 'later mutation';
      for (var index = 0; index < 3; index++) {
        final response = await handler(
          const RpcHttpRequest(method: 'GET', path: '/openapi.json'),
        );
        expect(jsonDecode(_bodyText(response)), {
          'info': {'title': 'API'},
        });
      }
      expect(counted.encodings, 1);
    });

    test(
      'cached OpenAPI byte bodies cannot be mutated between requests',
      () async {
        final handler = createRpcHttpHandler(
          procedures: RpcProcedureRegistry(const []),
          openApiDocument: const {'openapi': '3.0.3'},
          encodeJsonToBytes: true,
        );
        final first = await handler(
          const RpcHttpRequest(method: 'GET', path: '/openapi.json'),
        );
        expect(() => (first.body! as List<int>)[0] = 0, throwsUnsupportedError);
        final second = await handler(
          const RpcHttpRequest(method: 'GET', path: '/openapi.json'),
        );
        expect(jsonDecode(_bodyText(second)), {'openapi': '3.0.3'});
      },
    );
  });

  group('static file streaming and validators', () {
    late Directory directory;
    late File file;
    late RpcHttpHandler handler;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('orpc-stream-file');
      file = File('${directory.path}/asset.txt');
      await file.writeAsString('héllo');
      handler = createRpcHttpHandler(
        procedures: RpcProcedureRegistry(const []),
        staticAssets: RpcHttpStaticOptions(
          directory: directory.path,
          path: '/assets',
          cacheControl: 'public, max-age=60',
        ),
      );
    });
    tearDown(() => directory.delete(recursive: true));

    Future<RpcHttpResponse> get({
      String method = 'GET',
      Map<String, String> headers = const {},
    }) => handler(
      RpcHttpRequest(
        method: method,
        path: '/assets/asset.txt',
        headers: headers,
      ),
    );

    test(
      'GET streams bytes; HEAD returns same validators and byte length',
      () async {
        final response = await get();
        final content = response.content as RpcStreamingHttpBody;
        expect(content.flushEachChunk, isFalse);
        expect(await utf8.decodeStream(content.chunks), 'héllo');
        expect(response.headers['content-length'], '6');
        expect(response.headers['cache-control'], 'public, max-age=60');
        final head = await get(method: 'HEAD');
        expect(head.headers, response.headers);
        expect(head.body, isNull);
      },
    );

    test('ETag supports lists, weak comparison, wildcard and HEAD', () async {
      final head = await get(method: 'HEAD');
      final etag = head.headers['etag']!;
      for (final validator in [
        etag,
        etag.substring(2),
        '"other", $etag',
        '*',
      ]) {
        for (final method in ['GET', 'HEAD']) {
          final response = await get(
            method: method,
            headers: {'If-None-Match': validator},
          );
          expect(response.statusCode, HttpStatus.notModified);
          expect(response.body, isNull);
          expect(response.headers['etag'], etag);
        }
      }
    });

    test('date validators use seconds and ETag takes precedence', () async {
      final head = await get(method: 'HEAD');
      final lastModified = head.headers['last-modified']!;
      final unchanged = await get(headers: {'if-modified-since': lastModified});
      expect(unchanged.statusCode, HttpStatus.notModified);
      for (final headers in [
        {'if-modified-since': 'invalid'},
        {
          'if-modified-since': HttpDate.format(
            (await file.stat()).modified.subtract(const Duration(days: 1)),
          ),
        },
        {'if-none-match': '"different"', 'if-modified-since': lastModified},
      ]) {
        final response = await get(headers: headers);
        expect(response.statusCode, HttpStatus.ok);
        expect(
          await utf8.decodeStream(
            (response.content as RpcStreamingHttpBody).chunks,
          ),
          'héllo',
        );
      }
    });

    test(
      'changed file invalidates ETag without keeping cached content',
      () async {
        final head = await get(method: 'HEAD');
        await file.writeAsString('changed content');
        final response = await get(
          headers: {'if-none-match': head.headers['etag']!},
        );
        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers['etag'], isNot(head.headers['etag']));
        expect(
          await utf8.decodeStream(
            (response.content as RpcStreamingHttpBody).chunks,
          ),
          'changed content',
        );
      },
    );

    test('large file remains streamed through response wrappers', () async {
      final bytes = List<int>.generate(256 * 1024, (index) => index % 256);
      await file.writeAsBytes(bytes);
      final wrapped = (await get()).copyWith(headers: {'x-wrapped': 'yes'});
      expect((wrapped.content as RpcStreamingHttpBody).flushEachChunk, isFalse);
      expect(
        await (wrapped.content as RpcStreamingHttpBody).chunks
            .expand((chunk) => chunk)
            .toList(),
        bytes,
      );
    });
  });
}

String _bodyText(RpcHttpResponse response) => switch (response.body) {
  String value => value,
  List<int> value => utf8.decode(value),
  _ => throw StateError('Expected buffered JSON'),
};

final class _JsonBytes implements RpcJsonBytes {
  const _JsonBytes(this.value);
  final Object value;
  @override
  List<int> toJsonBytes() => JsonUtf8Encoder().convert(value);
}

final class _CountedJson {
  int encodings = 0;
  Map<String, Object?> toJson() {
    encodings++;
    return {'title': 'API'};
  }
}

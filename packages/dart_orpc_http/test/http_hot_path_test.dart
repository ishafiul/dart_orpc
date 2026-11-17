import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  Future<Uri> serve(RpcHttpApp app) async {
    final server = await app.listen(0, hostname: '127.0.0.1');
    addTearDown(() => server.close(force: true));
    return Uri.parse('http://127.0.0.1:${server.port}');
  }

  HttpClient client() {
    final result = HttpClient();
    addTearDown(() => result.close(force: true));
    return result;
  }

  RpcHttpApp echoApp() => RpcHttpApp(
    procedures: RpcProcedureRegistry(const []),
    middleware: [
      (next) =>
          (request) async => RpcHttpResponse(
            statusCode: 200,
            body: jsonEncode({
              'body': request.body,
              'remoteAddress': request.remoteAddress,
              'requestId': request.requestId,
            }),
          ),
    ],
  );

  group('Given an app without metrics or completion hooks', () {
    test(
      'When requests arrive Then each gets a distinct 32-character request ID',
      () async {
        final base = await serve(echoApp());
        final http = client();

        final ids = <String?>[];
        for (var i = 0; i < 3; i++) {
          final response = await (await http.getUrl(base)).close();
          await response.drain<void>();
          ids.add(response.headers.value('x-request-id'));
        }

        expect(ids, everyElement(matches(RegExp(r'^[0-9a-f]{32}$'))));
        expect(ids.toSet(), hasLength(3));
      },
    );

    test(
      'When a handler reads remoteAddress Then it gets the peer address',
      () async {
        final base = await serve(echoApp());

        final response = await (await client().getUrl(base)).close();
        final body = jsonDecode(await utf8.decodeStream(response));

        expect(body['remoteAddress'], '127.0.0.1');
        expect(body['requestId'], response.headers.value('x-request-id'));
      },
    );

    test(
      'When a GET has no body Then the handler sees an empty body',
      () async {
        final base = await serve(echoApp());

        final response = await (await client().getUrl(base)).close();
        final body = jsonDecode(await utf8.decodeStream(response));

        expect(response.statusCode, 200);
        expect(body['body'], '');
      },
    );

    test(
      'When a GET carries a chunked body Then the handler still reads it',
      () async {
        final base = await serve(echoApp());

        final request = await client().getUrl(base);
        request.headers.chunkedTransferEncoding = true;
        request.write('chunked');
        final response = await request.close();
        final body = jsonDecode(await utf8.decodeStream(response));

        expect(body['body'], 'chunked');
      },
    );
  });

  group('Given JSON responses encoded to bytes', () {
    test('When responses of different sizes follow each other Then each body is exact', () async {
      final app = RpcHttpApp(
        procedures: RpcProcedureRegistry(const []),
        middleware: [
          (next) =>
              (request) async => RpcHttpResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                body: utf8.encode(
                  jsonEncode({'echo': request.uri?.queryParameters['v']}),
                ),
              ),
        ],
      );
      final base = await serve(app);
      final http = client();

      for (final value in ['a' * 3000, 'b', 'c' * 20]) {
        final response = await (await http.getUrl(
          base.replace(queryParameters: {'v': value}),
        )).close();
        final body = await utf8.decodeStream(response);
        expect(body, jsonEncode({'echo': value}));
      }
    });

    test(
      'When a header the route reads is absent Then the lookup returns null',
      () async {
        final app = RpcHttpApp(
          procedures: RpcProcedureRegistry(const []),
          middleware: [
            (next) =>
                (request) async => RpcHttpResponse(
                  statusCode: 200,
                  body: jsonEncode({
                    'tenant': lookupRestHeader(request.headers, 'X-Tenant'),
                    'missing': lookupRestHeader(request.headers, 'x-missing'),
                  }),
                ),
          ],
        );
        final base = await serve(app);

        final request = await client().getUrl(base);
        request.headers.set('X-Tenant', 'acme');
        final response = await request.close();
        final body = jsonDecode(await utf8.decodeStream(response));

        expect(body, {'tenant': 'acme', 'missing': null});
      },
    );
  });

  restInputBodyAndResponseControlTests();
}

void restInputBodyAndResponseControlTests() {
  RpcHttpRequest post(List<int> bytes) =>
      RpcHttpRequest(method: 'POST', path: '/users', bodyBytes: bytes);

  group('Given decodeRestRpcInputBody', () {
    test('When the body is blank Then it returns an empty, extendable map', () {
      final input = decodeRestRpcInputBody(
        post(utf8.encode(' \n')),
        route: 'POST /users',
        parameterName: 'input',
      );

      input['id'] = 'path';
      expect(input, {'id': 'path'});
    });

    test('When the body is a JSON object Then it is decoded once', () {
      final input = decodeRestRpcInputBody(
        post(utf8.encode('{"name":"Ada"}')),
        route: 'POST /users',
        parameterName: 'input',
      );

      input['id'] = 'path';
      expect(input, {'name': 'Ada', 'id': 'path'});
    });

    test('When the body has a byte order mark Then it still decodes', () {
      final input = decodeRestRpcInputBody(
        post([0xef, 0xbb, 0xbf, ...utf8.encode('{"name":"Ada"}')]),
        route: 'POST /users',
        parameterName: 'input',
      );

      expect(input, {'name': 'Ada'});
    });

    test('When the body is invalid JSON Then the REST error is unchanged', () {
      expect(
        () => decodeRestRpcInputBody(
          post(utf8.encode('{')),
          route: 'POST /users',
          parameterName: 'input',
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.message,
            'message',
            'REST request body for "POST /users" must be valid JSON.',
          ),
        ),
      );
    });

    test('When the body is a JSON array Then it is rejected as before', () {
      expect(
        () => decodeRestRpcInputBody(
          post(utf8.encode('[]')),
          route: 'POST /users',
          parameterName: 'input',
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.message,
            'message',
            'POST /users body must be a JSON object.',
          ),
        ),
      );
    });
  });

  group('Given RpcHttpResponseControl', () {
    const response = RpcHttpResponse(statusCode: 200, body: 'ok');

    test('When nothing is set Then apply returns the same response', () {
      expect(
        identical(RpcHttpResponseControl().apply(response), response),
        isTrue,
      );
    });

    test('When a header is set Then apply adds it', () {
      final control = RpcHttpResponseControl()..headers['x-id'] = '1';

      final applied = control.apply(response);

      expect(applied.headers['x-id'], '1');
      expect(applied.body, 'ok');
    });
  });

  test('Given RpcHttpApp When no option is passed Then JSON is bytes', () {
    final app = RpcHttpApp(procedures: RpcProcedureRegistry(const []));
    addTearDown(app.close);

    expect(app.encodeJsonToBytes, isTrue);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  group('Given the generated basic app over HTTP', () {
    late HttpServer server;
    late HttpRpcTransport transport;
    late AppClient client;

    setUp(() async {
      final app = buildBasicApp();
      server = await app.listen(
        0,
        hostname: InternetAddress.loopbackIPv4.address,
      );
      transport = HttpRpcTransport(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      client = AppClient(transport: transport);
    });

    tearDown(() async {
      transport.close();
      await server.close(force: true);
    });

    test(
      'When the generated client requests an existing user then it returns the typed DTO',
      () async {
        final user = await client.user.getById(const GetUserDto(id: '1'));

        expect(user.id, '1');
        expect(user.name, 'Ada Lovelace');
      },
    );

    test(
      'When the generated client requests a missing user then it surfaces RpcException',
      () async {
        await expectLater(
          () => client.user.getById(const GetUserDto(id: '404')),
          throwsA(
            isA<RpcException>()
                .having((error) => error.code, 'code', RpcErrorCode.notFound)
                .having(
                  (error) => error.message,
                  'message',
                  'User "404" was not found.',
                ),
          ),
        );
      },
    );

    test(
      'When raw RPC input fails Luthor validation then the server returns a bad request with the validation message',
      () async {
        final httpClient = HttpClient();
        addTearDown(httpClient.close);

        final request = await httpClient.post(
          server.address.address,
          server.port,
          '/rpc',
        );
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'method': 'user.getById',
            'input': {'id': ''},
          }),
        );

        final response = await request.close();
        final body =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;

        expect(response.statusCode, HttpStatus.badRequest);
        expect(body['error'], {
          'code': 'BAD_REQUEST',
          'message':
              'Invalid RPC input for "user.getById": id: id must be at least 1 character long',
        });
      },
    );

    test(
      'When requesting the generated REST route then it returns the raw JSON payload',
      () async {
        final httpClient = HttpClient();
        addTearDown(httpClient.close);

        final request = await httpClient.getUrl(
          Uri.parse(
            'http://${server.address.address}:${server.port}/users/1?include=compact',
          ),
        );

        final response = await request.close();
        final body =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;

        expect(response.statusCode, HttpStatus.ok);
        expect(body, {'id': '1', 'name': 'Ada'});
      },
    );

    test(
      'When requesting a missing resource through the generated REST route then it returns the error payload with the HTTP status',
      () async {
        final httpClient = HttpClient();
        addTearDown(httpClient.close);

        final request = await httpClient.getUrl(
          Uri.parse(
            'http://${server.address.address}:${server.port}/users/404',
          ),
        );

        final response = await request.close();
        final body =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;

        expect(response.statusCode, HttpStatus.notFound);
        expect(body['error'], {
          'code': 'NOT_FOUND',
          'message': 'User "404" was not found.',
        });
      },
    );

    test(
      'When requesting /openapi.json then it returns the generated OpenAPI document',
      () async {
        final httpClient = HttpClient();
        addTearDown(httpClient.close);

        final request = await httpClient.getUrl(
          Uri.parse(
            'http://${server.address.address}:${server.port}/openapi.json',
          ),
        );

        final response = await request.close();
        final body =
            jsonDecode(await utf8.decoder.bind(response).join()) as Map;

        expect(response.statusCode, HttpStatus.ok);
        expect(body['openapi'], '3.0.3');
        expect((body['paths'] as Map).containsKey('/users/{id}'), isTrue);
        expect(
          (((body['components'] as Map)['schemas'] as Map).containsKey(
            'GetUserDto',
          )),
          isTrue,
        );
        expect(
          (((body['components'] as Map)['schemas'] as Map).containsKey(
            'UserResponseDto',
          )),
          isTrue,
        );
      },
    );

    test(
      'When requesting /docs then it returns the Scalar docs HTML',
      () async {
        final httpClient = HttpClient();
        addTearDown(httpClient.close);

        final request = await httpClient.getUrl(
          Uri.parse('http://${server.address.address}:${server.port}/docs'),
        );

        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();

        expect(response.statusCode, HttpStatus.ok);
        expect(response.headers.contentType?.mimeType, 'text/html');
        expect(body, contains('@scalar/api-reference'));
        expect(body, contains('/openapi.json'));
      },
    );
  });
}

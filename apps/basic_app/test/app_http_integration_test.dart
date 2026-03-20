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
  });
}

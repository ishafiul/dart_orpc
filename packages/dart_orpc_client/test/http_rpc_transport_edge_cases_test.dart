import 'dart:convert';

import 'package:dart_orpc_client/dart_orpc_client.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('Given HttpRpcTransport edge cases', () {
    test(
      'When the RPC request cannot be JSON encoded then it throws RpcClientException',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            fail('The request should fail before reaching the HTTP client.');
          }),
        );

        await expectLater(
          () => transport.send(
            RpcRequest(method: 'user.getById', input: Object()),
          ),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains('Failed to encode RPC request for "user.getById"'),
            ),
          ),
        );
      },
    );

    test(
      'When the HTTP client throws then it wraps the failure as RpcClientException',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            throw Exception('network down');
          }),
        );

        await expectLater(
          () => transport.send(const RpcRequest(method: 'user.getById')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains(
                'Failed to send RPC request to http://localhost:3000/rpc',
              ),
            ),
          ),
        );
      },
    );

    test(
      'When the HTTP response body is empty then it throws RpcClientException',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async => http.Response('', 200)),
        );

        await expectLater(
          () => transport.send(const RpcRequest(method: 'user.getById')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              'RPC response from http://localhost:3000/rpc was empty.',
            ),
          ),
        );
      },
    );

    test(
      'When the HTTP response body is invalid JSON then it throws RpcClientException',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async => http.Response('{', 200)),
        );

        await expectLater(
          () => transport.send(const RpcRequest(method: 'user.getById')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              'RPC response from http://localhost:3000/rpc was not valid JSON.',
            ),
          ),
        );
      },
    );

    test(
      'When the RPC error envelope has an unknown code then it throws RpcClientException',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'error': {'code': 'UNKNOWN', 'message': 'Bad state.'},
              }),
              500,
              headers: const {'content-type': 'application/json'},
            );
          }),
        );

        await expectLater(
          () => transport.send(const RpcRequest(method: 'user.getById')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              'RPC response from http://localhost:3000/rpc returned unknown error code "UNKNOWN".',
            ),
          ),
        );
      },
    );

    test(
      'When the server returns an HTTP error without an RPC error envelope then it throws RpcClientException',
      () async {
        final transport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
          client: MockClient((request) async {
            return http.Response(
              jsonEncode({'message': 'boom'}),
              500,
              headers: const {'content-type': 'application/json'},
            );
          }),
        );

        await expectLater(
          () => transport.send(const RpcRequest(method: 'user.getById')),
          throwsA(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              'RPC response from http://localhost:3000/rpc returned HTTP 500 without an RPC error envelope.',
            ),
          ),
        );
      },
    );

    test(
      'When customizing the endpoint path then endpointUri stays rooted at /rpc',
      () {
        final defaultTransport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000',
        );
        final customTransport = HttpRpcTransport(
          baseUrl: 'http://localhost:3000/api/',
          endpointPath: 'rpc',
        );

        expect(
          defaultTransport.endpointUri.toString(),
          'http://localhost:3000/rpc',
        );
        expect(
          customTransport.endpointUri.toString(),
          'http://localhost:3000/rpc',
        );

        defaultTransport.close();
        customTransport.close();
      },
    );
  });
}

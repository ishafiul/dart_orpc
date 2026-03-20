import 'package:dart_orpc/dart_orpc.dart';
import 'package:test/test.dart';

void main() {
  group('Given the dart_orpc facade package', () {
    test(
      'When importing it then the public runtime APIs are available',
      () async {
        const module = Module();
        const controller = Controller('user');
        const method = RpcMethod(name: 'getById');
        const inputAnnotation = RpcInput();
        const context = RpcContext(headers: {'x-trace-id': 'trace-1'});
        const request = RpcRequest(method: 'user.getById', input: {'id': '1'});
        const successResponse = RpcSuccessResponse(data: {'id': '1'});
        const errorResponse = RpcErrorResponse(
          error: RpcErrorBody(code: 'NOT_FOUND', message: 'missing'),
        );
        const httpRequest = RpcHttpRequest(method: 'POST', path: '/rpc');
        const httpResponse = RpcHttpResponse(statusCode: 200);
        final transport = HttpRpcTransport(baseUrl: 'http://localhost:3000');
        final caller = RpcCaller(const _StaticTransport({'ok': true}));

        final result = await caller.call<Map<String, Object?>>(
          method: 'health.check',
          decode: (json) => expectJsonObject(json, context: 'health response'),
        );

        expect(module.controllers, isEmpty);
        expect(controller.namespace, 'user');
        expect(method.name, 'getById');
        expect(inputAnnotation, isA<RpcInput>());
        expect(context.headers['x-trace-id'], 'trace-1');
        expect(request.toJson(), {
          'method': 'user.getById',
          'input': {'id': '1'},
        });
        expect(successResponse.toJson(), {
          'data': {'id': '1'},
        });
        expect(errorResponse.toJson(), {
          'error': {'code': 'NOT_FOUND', 'message': 'missing'},
        });
        expect(httpRequest.path, '/rpc');
        expect(httpResponse.statusCode, 200);
        expect(transport.endpointUri.toString(), 'http://localhost:3000/rpc');
        expect(result, {'ok': true});

        transport.close();
      },
    );
  });
}

final class _StaticTransport implements RpcTransport {
  const _StaticTransport(this.response);

  final Object? response;

  @override
  Future<Object?> send(RpcRequest request) async => response;
}

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given JSON utility helpers', () {
    test(
      'When expectJsonObject receives a loose map then it returns a typed map',
      () {
        final object = expectJsonObject(<Object?, Object?>{
          'id': '1',
        }, context: 'test payload');

        expect(object, {'id': '1'});
      },
    );

    test(
      'When expectJsonObject receives a non-map then it throws bad request',
      () {
        expect(
          () => expectJsonObject('invalid', context: 'test payload'),
          throwsA(
            isA<RpcException>()
                .having((error) => error.code, 'code', RpcErrorCode.badRequest)
                .having(
                  (error) => error.message,
                  'message',
                  'test payload must be a JSON object.',
                ),
          ),
        );
      },
    );

    test(
      'When normalizeJsonObject receives nested toJson values then it canonicalizes them',
      () {
        final normalized = normalizeJsonObject({
          'items': [const _NestedJsonValue(id: '1')],
        }, context: 'test payload');

        expect(normalized, {
          'items': [
            {'id': '1'},
          ],
        });
      },
    );

    test(
      'When expectNoRpcInput receives null or an empty object then it accepts the payload',
      () {
        expect(expectNoRpcInput(null, context: 'health.check'), isNull);
        expect(expectNoRpcInput(const {}, context: 'health.check'), isNull);
      },
    );

    test(
      'When expectNoRpcInput receives a non-empty payload then it throws bad request',
      () {
        expect(
          () => expectNoRpcInput({
            'unexpected': true,
          }, context: 'RPC method "health.check"'),
          throwsA(
            isA<RpcException>()
                .having((error) => error.code, 'code', RpcErrorCode.badRequest)
                .having(
                  (error) => error.message,
                  'message',
                  'RPC method "health.check" does not accept input.',
                ),
          ),
        );
      },
    );

    test(
      'When expectStringField requires a non-empty value then it rejects blanks',
      () {
        expect(
          () => expectStringField({'id': '   '}, 'id', nonEmpty: true),
          throwsA(
            isA<RpcException>().having(
              (error) => error.message,
              'message',
              'Field "id" must not be empty.',
            ),
          ),
        );
      },
    );
  });

  group('Given RpcRequest parsing', () {
    test(
      'When RpcRequest.fromJson receives a valid payload then it preserves method and input',
      () {
        final request = RpcRequest.fromJson({
          'method': 'user.getById',
          'input': {'id': '1'},
        });

        expect(request.method, 'user.getById');
        expect(request.input, {'id': '1'});
        expect(request.toJson(), {
          'method': 'user.getById',
          'input': {'id': '1'},
        });
      },
    );

    test(
      'When RpcRequest.fromJson receives a blank method then it throws bad request',
      () {
        expect(
          () => RpcRequest.fromJson({'method': '   '}),
          throwsA(
            isA<RpcException>().having(
              (error) => error.message,
              'message',
              'RPC request "method" must be a non-empty string.',
            ),
          ),
        );
      },
    );
  });

  group('Given RPC response primitives', () {
    test(
      'When serializing success and error envelopes then they match the wire format',
      () {
        const success = RpcSuccessResponse(data: {'id': '1'});
        const error = RpcErrorResponse(
          error: RpcErrorBody(code: 'NOT_FOUND', message: 'missing'),
        );

        expect(success.toJson(), {
          'data': {'id': '1'},
        });
        expect(error.toJson(), {
          'error': {'code': 'NOT_FOUND', 'message': 'missing'},
        });
      },
    );
  });

  group('Given RPC error metadata', () {
    test('When parsing known wire names then RpcErrorCode resolves them', () {
      expect(RpcErrorCode.tryParseWireName('CONFLICT'), RpcErrorCode.conflict);
      expect(RpcErrorCode.tryParseWireName('UNKNOWN'), isNull);
    });

    test(
      'When using RpcException factories then status, response, and string output stay aligned',
      () {
        final error = RpcException.notFound('User missing.');

        expect(error.statusCode, 404);
        expect(error.toResponse().toJson(), {
          'error': {'code': 'NOT_FOUND', 'message': 'User missing.'},
        });
        expect(error.toString(), 'RpcException(NOT_FOUND): User missing.');
      },
    );
  });

  group('Given RpcContext defaults', () {
    test(
      'When constructing RpcContext with only headers then it defaults to POST /rpc',
      () {
        const context = RpcContext(headers: {'accept': 'application/json'});

        expect(context.httpMethod, 'POST');
        expect(context.path, '/rpc');
      },
    );
  });

  group('Given RpcProcedure input and output handling', () {
    const context = RpcContext(headers: {'x-trace-id': 'trace-1'});

    test(
      'When invoke succeeds then it decodes input, calls the handler, and encodes output',
      () async {
        final procedure = RpcProcedure<JsonObject, String>(
          method: 'user.echo',
          decodeInput: (rawInput) =>
              expectJsonObject(rawInput, context: 'user.echo input'),
          encodeOutput: (output) => {'value': output},
          handler: (receivedContext, input) async {
            expect(receivedContext.headers['x-trace-id'], 'trace-1');
            return input['id'] as String;
          },
        );

        final result = await procedure.invoke(context, {'id': '1'});

        expect(result, {'value': '1'});
      },
    );

    test(
      'When decodeInput throws a non-RpcException then invoke wraps it as bad request',
      () async {
        final procedure = RpcProcedure<Object?, Object?>(
          method: 'user.decode',
          decodeInput: (_) => throw StateError('bad input'),
          encodeOutput: (output) => output,
          handler: (_, input) async => input,
        );

        await expectLater(
          () => procedure.invoke(context, {'id': '1'}),
          throwsA(
            isA<RpcException>()
                .having((error) => error.code, 'code', RpcErrorCode.badRequest)
                .having(
                  (error) => error.message,
                  'message',
                  'Failed to decode RPC input for "user.decode".',
                ),
          ),
        );
      },
    );

    test(
      'When encodeOutput throws a non-RpcException then invoke wraps it as internal error',
      () async {
        final procedure = RpcProcedure<Object?, Object?>(
          method: 'user.encode',
          decodeInput: (rawInput) => rawInput,
          encodeOutput: (_) => throw StateError('bad output'),
          handler: (_, input) async => input,
        );

        await expectLater(
          () => procedure.invoke(context, {'id': '1'}),
          throwsA(
            isA<RpcException>()
                .having(
                  (error) => error.code,
                  'code',
                  RpcErrorCode.internalError,
                )
                .having(
                  (error) => error.message,
                  'message',
                  'Failed to encode RPC response for "user.encode".',
                ),
          ),
        );
      },
    );
  });
}

final class _NestedJsonValue {
  const _NestedJsonValue({required this.id});

  final String id;

  JsonObject toJson() => {'id': id};
}

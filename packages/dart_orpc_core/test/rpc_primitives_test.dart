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

  group('Given procedure custom metadata', () {
    test(
      'When custom metadata is stored then keyed lookups return the matching value maps',
      () {
        const procedure = ProcedureMetadata(
          rpcMethod: 'todo.list',
          controllerNamespace: 'todo',
          methodName: 'list',
          outputTypeCode: 'TodoListResponseDto',
          customMetadata: [
            ProcedureCustomMetadata(
              key: 'permissions',
              value: {
                'allOf': ['tenant.active'],
              },
            ),
            ProcedureCustomMetadata(
              key: 'permissions',
              value: {
                'anyOf': ['todo.read', 'todo.admin'],
              },
            ),
            ProcedureCustomMetadata(key: 'rateLimit', value: {'limit': 10}),
          ],
        );

        expect(procedure.firstMetadataValue('rateLimit'), {'limit': 10});
        expect(procedure.firstMetadataValue('missing'), isNull);
        expect(procedure.metadataValues('permissions'), [
          {
            'allOf': ['tenant.active'],
          },
          {
            'anyOf': ['todo.read', 'todo.admin'],
          },
        ]);
      },
    );
  });

  group('Given RpcProcedure input and output handling', () {
    const context = RpcContext(headers: {'x-trace-id': 'trace-1'});
    const procedureMetadata = ProcedureMetadata(
      rpcMethod: 'user.echo',
      controllerNamespace: 'user',
      methodName: 'echo',
      outputTypeCode: 'String',
      guardTypes: ['AuthGuard'],
      customMetadata: [
        ProcedureCustomMetadata(
          key: 'permissions',
          value: {
            'allOf': ['tenant.active'],
          },
        ),
      ],
    );

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
      'When beforeInvoke is configured then it runs before the controller handler',
      () async {
        final callOrder = <String>[];
        final procedure = RpcProcedure<JsonObject, JsonObject>(
          method: 'user.guarded',
          decodeInput: (rawInput) =>
              expectJsonObject(rawInput, context: 'user.guarded input'),
          encodeOutput: (output) => output,
          beforeInvoke: (receivedContext, input) async {
            expect(receivedContext.headers['x-trace-id'], 'trace-1');
            expect(input['id'], '1');
            callOrder.add('beforeInvoke');
          },
          handler: (_, input) async {
            callOrder.add('handler');
            return input;
          },
        );

        final result = await procedure.invoke(context, {'id': '1'});

        expect(result, {'id': '1'});
        expect(callOrder, ['beforeInvoke', 'handler']);
      },
    );

    test(
      'When runRpcGuards is called then it executes guards in order with the resolved procedure metadata',
      () async {
        final calls = <String>[];

        await runRpcGuards(
          [_RecordingGuard(calls, 'first'), _RecordingGuard(calls, 'second')],
          rpcContext: context,
          procedure: procedureMetadata,
          input: const {'id': '1'},
        );

        expect(calls, [
          'first:user.echo:trace-1:AuthGuard:tenant.active',
          'second:user.echo:trace-1:AuthGuard:tenant.active',
        ]);
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

final class _RecordingGuard implements RpcGuard {
  const _RecordingGuard(this.calls, this.name);

  final List<String> calls;
  final String name;

  @override
  void canActivate(RpcGuardContext context) {
    final permissions =
        context.procedure.firstMetadataValue('permissions')?['allOf'] as List?;
    calls.add(
      '$name:${context.procedure.rpcMethod}:${context.rpcContext.headers['x-trace-id']}:${context.procedure.guardTypes.single}:${permissions?.single}',
    );
  }
}

import 'dart:async';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a registered server-streaming procedure', () {
    late RpcCancellationSource cancellation;
    late List<String> trace;
    late RpcProcedureRegistry registry;

    setUp(() {
      cancellation = RpcCancellationSource();
      trace = [];
      const metadata = ProcedureMetadata(
        rpcMethod: 'events.watch',
        controllerNamespace: 'events',
        methodName: 'watch',
        outputTypeCode: 'String',
        kind: RpcProcedureKind.serverStream,
      );
      registry = RpcProcedureRegistry([
        RpcStreamProcedure<JsonObject, String>(
          method: metadata.rpcMethod,
          metadata: metadata,
          decodeInput: (raw) {
            trace.add('decode');
            return expectJsonObject(raw, context: 'stream input');
          },
          encodeOutput: (output) {
            trace.add('encode:$output');
            return output;
          },
          beforeInvoke: (_, _) => trace.add('before'),
          handler: (_, input) async* {
            trace.add('handler');
            yield '${input['prefix']}-1';
            yield '${input['prefix']}-2';
          },
        ),
      ]);
    });

    group('When the stream is dispatched', () {
      late List<Object?> events;

      setUp(() async {
        events = await registry
            .dispatchStream(
              RpcContext(headers: const {}, cancellation: cancellation.signal),
              const RpcRequest(
                method: 'events.watch',
                input: {'prefix': 'event'},
              ),
            )
            .toList();
      });

      test('Then it emits encoded events in source order', () {
        expect(events, ['event-1', 'event-2']);
      });

      test('Then setup runs once and each event is encoded once', () {
        expect(trace, [
          'decode',
          'before',
          'handler',
          'encode:event-1',
          'encode:event-2',
        ]);
        expect(registry.procedures.single.kind, RpcProcedureKind.serverStream);
      });
    });

    test('When unary dispatch is used then it rejects the stream kind', () {
      expect(
        () => registry.dispatchUnary(
          RpcContext(headers: const {}),
          const RpcRequest(method: 'events.watch'),
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.badRequest,
          ),
        ),
      );
    });

    test('When cancelled before listening then it emits cancellation', () {
      cancellation.cancel();

      expect(
        registry.dispatchStream(
          RpcContext(headers: const {}, cancellation: cancellation.signal),
          const RpcRequest(method: 'events.watch'),
        ),
        emitsError(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.cancelled,
          ),
        ),
      );
    });

    test(
      'When a consumer cancels while the source is idle then the source subscription is released',
      () async {
        final sourceCancelled = Completer<void>();
        late StreamController<String> source;
        source = StreamController<String>(
          onListen: () => source.add('first'),
          onCancel: sourceCancelled.complete,
        );
        const metadata = ProcedureMetadata(
          rpcMethod: 'events.idle',
          controllerNamespace: 'events',
          methodName: 'idle',
          outputTypeCode: 'String',
          kind: RpcProcedureKind.serverStream,
        );
        final idleRegistry = RpcProcedureRegistry([
          RpcStreamProcedure<Null, String>(
            method: metadata.rpcMethod,
            metadata: metadata,
            decodeInput: (_) => null,
            encodeOutput: (output) => output,
            handler: (_, _) => source.stream,
          ),
        ]);
        final firstEvent = Completer<void>();
        final subscription = idleRegistry
            .dispatchStream(
              RpcContext(headers: const {}),
              const RpcRequest(method: 'events.idle'),
            )
            .listen((_) => firstEvent.complete());

        await firstEvent.future;
        await subscription.cancel();

        await sourceCancelled.future.timeout(const Duration(seconds: 2));
        expect(source.hasListener, isFalse);
      },
    );

    test(
      'When guards and beforeInvoke are configured then setup runs once in order',
      () async {
        final setupTrace = <String>[];
        const metadata = ProcedureMetadata(
          rpcMethod: 'events.guarded',
          controllerNamespace: 'events',
          methodName: 'guarded',
          outputTypeCode: 'String',
          kind: RpcProcedureKind.serverStream,
        );
        final guardedRegistry = RpcProcedureRegistry([
          RpcStreamProcedure<JsonObject, String>(
            method: metadata.rpcMethod,
            metadata: metadata,
            decodeInput: (raw) {
              setupTrace.add('decode');
              return expectJsonObject(raw, context: 'guarded input');
            },
            encodeOutput: (output) => output,
            guards: [_TraceGuard(setupTrace)],
            beforeInvoke: (_, _) => setupTrace.add('before'),
            handler: (_, _) {
              setupTrace.add('handler');
              return Stream.value('event');
            },
          ),
        ]);

        final events = await guardedRegistry
            .dispatchStream(
              RpcContext(headers: const {}),
              const RpcRequest(method: 'events.guarded', input: {'id': 'one'}),
            )
            .toList();

        expect(events, ['event']);
        expect(setupTrace, ['decode', 'guard', 'before', 'handler']);
      },
    );

    test(
      'When event encoding fails then the call terminates and cancels its source',
      () async {
        final sourceCancelled = Completer<void>();
        late StreamController<String> source;
        source = StreamController<String>(
          onListen: () {
            source
              ..add('valid')
              ..add('invalid')
              ..add('ignored');
          },
          onCancel: sourceCancelled.complete,
        );
        const metadata = ProcedureMetadata(
          rpcMethod: 'events.invalid',
          controllerNamespace: 'events',
          methodName: 'invalid',
          outputTypeCode: 'String',
          kind: RpcProcedureKind.serverStream,
        );
        final invalidRegistry = RpcProcedureRegistry([
          RpcStreamProcedure<Null, String>(
            method: metadata.rpcMethod,
            metadata: metadata,
            decodeInput: (_) => null,
            encodeOutput: (output) {
              if (output == 'invalid') {
                throw StateError('cannot encode');
              }
              return output;
            },
            handler: (_, _) => source.stream,
          ),
        ]);

        await expectLater(
          invalidRegistry.dispatchStream(
            RpcContext(headers: const {}),
            const RpcRequest(method: 'events.invalid'),
          ),
          emitsInOrder([
            'valid',
            emitsError(
              isA<RpcException>().having(
                (error) => error.code,
                'code',
                RpcErrorCode.internalError,
              ),
            ),
          ]),
        );

        await sourceCancelled.future.timeout(const Duration(seconds: 2));
      },
    );

    test(
      'When the cancellation signal fires during production then the source is released',
      () async {
        final sourceStarted = Completer<void>();
        final sourceCancelled = Completer<void>();
        late StreamController<String> source;
        source = StreamController<String>(
          onListen: () {
            source.add('first');
            sourceStarted.complete();
          },
          onCancel: sourceCancelled.complete,
        );
        const metadata = ProcedureMetadata(
          rpcMethod: 'events.cancel',
          controllerNamespace: 'events',
          methodName: 'cancel',
          outputTypeCode: 'String',
          kind: RpcProcedureKind.serverStream,
        );
        final cancelRegistry = RpcProcedureRegistry([
          RpcStreamProcedure<Null, String>(
            method: metadata.rpcMethod,
            metadata: metadata,
            decodeInput: (_) => null,
            encodeOutput: (output) => output,
            handler: (_, _) => source.stream,
          ),
        ]);
        final expectation = expectLater(
          cancelRegistry.dispatchStream(
            RpcContext(headers: const {}, cancellation: cancellation.signal),
            const RpcRequest(method: 'events.cancel'),
          ),
          emitsInOrder([
            'first',
            emitsError(
              isA<RpcException>().having(
                (error) => error.code,
                'code',
                RpcErrorCode.cancelled,
              ),
            ),
          ]),
        );

        await sourceStarted.future;
        cancellation.cancel();

        await expectation.timeout(const Duration(seconds: 2));
        await sourceCancelled.future.timeout(const Duration(seconds: 2));
      },
    );

    test('When a source is empty then the call completes without events', () {
      const metadata = ProcedureMetadata(
        rpcMethod: 'events.empty',
        controllerNamespace: 'events',
        methodName: 'empty',
        outputTypeCode: 'String',
        kind: RpcProcedureKind.serverStream,
      );
      final emptyRegistry = RpcProcedureRegistry([
        RpcStreamProcedure<Null, String>(
          method: metadata.rpcMethod,
          metadata: metadata,
          decodeInput: (_) => null,
          encodeOutput: (output) => output,
          handler: (_, _) => const Stream.empty(),
        ),
      ]);

      expect(
        emptyRegistry.dispatchStream(
          RpcContext(headers: const {}),
          const RpcRequest(method: 'events.empty'),
        ),
        emitsDone,
      );
    });
  });

  group('Given a cooperative RPC cancellation source', () {
    test('When cancelled repeatedly then it notifies exactly once', () async {
      final source = RpcCancellationSource();
      var notifications = 0;
      source.signal.cancelled.then((_) => notifications++);

      source.cancel();
      source.cancel();
      await source.signal.cancelled;
      await Future<void>.delayed(Duration.zero);

      expect(source.isCancelled, isTrue);
      expect(notifications, 1);
      expect(source.signal.throwIfCancelled, throwsA(isA<RpcException>()));
    });
  });

  group('Given a unary procedure registry', () {
    test('When stream dispatch is used then it rejects the unary kind', () {
      const metadata = ProcedureMetadata(
        rpcMethod: 'events.once',
        controllerNamespace: 'events',
        methodName: 'once',
        outputTypeCode: 'String',
      );
      final registry = RpcProcedureRegistry([
        RpcUnaryProcedure<Null, String>(
          method: metadata.rpcMethod,
          metadata: metadata,
          decodeInput: (_) => null,
          encodeOutput: (output) => output,
          handler: (_, _) => 'done',
        ),
      ]);

      expect(
        registry.dispatchStream(
          RpcContext(headers: const {}),
          const RpcRequest(method: 'events.once'),
        ),
        emitsError(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.badRequest,
          ),
        ),
      );
    });

    test(
      'When cancellation happens while the handler is active then its result is discarded',
      () async {
        final cancellation = RpcCancellationSource();
        final handlerStarted = Completer<void>();
        final releaseHandler = Completer<void>();
        const metadata = ProcedureMetadata(
          rpcMethod: 'events.slow',
          controllerNamespace: 'events',
          methodName: 'slow',
          outputTypeCode: 'String',
        );
        final registry = RpcProcedureRegistry([
          RpcUnaryProcedure<Null, String>(
            method: metadata.rpcMethod,
            metadata: metadata,
            decodeInput: (_) => null,
            encodeOutput: (output) => output,
            handler: (_, _) async {
              handlerStarted.complete();
              await releaseHandler.future;
              return 'too late';
            },
          ),
        ]);
        final result = registry.dispatchUnary(
          RpcContext(headers: const {}, cancellation: cancellation.signal),
          const RpcRequest(method: 'events.slow'),
        );

        await handlerStarted.future;
        cancellation.cancel();
        releaseHandler.complete();

        await expectLater(
          result,
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.cancelled,
            ),
          ),
        );
      },
    );
  });

  test(
    'Given unary and stream procedures When names collide then registration fails',
    () {
      const unaryMetadata = ProcedureMetadata(
        rpcMethod: 'events.same',
        controllerNamespace: 'events',
        methodName: 'sameUnary',
        outputTypeCode: 'String',
      );
      const streamMetadata = ProcedureMetadata(
        rpcMethod: 'events.same',
        controllerNamespace: 'events',
        methodName: 'sameStream',
        outputTypeCode: 'String',
        kind: RpcProcedureKind.serverStream,
      );

      expect(
        () => RpcProcedureRegistry([
          RpcUnaryProcedure<Null, String>(
            method: unaryMetadata.rpcMethod,
            metadata: unaryMetadata,
            decodeInput: (_) => null,
            encodeOutput: (output) => output,
            handler: (_, _) => 'one',
          ),
          RpcStreamProcedure<Null, String>(
            method: streamMetadata.rpcMethod,
            metadata: streamMetadata,
            decodeInput: (_) => null,
            encodeOutput: (output) => output,
            handler: (_, _) => Stream.value('one'),
          ),
        ]),
        throwsStateError,
      );
    },
  );
}

final class _TraceGuard implements RpcGuard {
  const _TraceGuard(this.trace);

  final List<String> trace;

  @override
  void canActivate(RpcGuardContext context) {
    trace.add('guard');
  }
}

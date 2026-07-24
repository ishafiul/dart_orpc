import 'dart:async';

import 'procedure_metadata.dart';
import 'rpc_cancellation.dart';
import 'rpc_context.dart';
import 'rpc_exception.dart';
import 'rpc_guard.dart';

typedef RpcInputDecoder<I> = I Function(Object? rawInput);
typedef RpcOutputEncoder<O> = Object? Function(O output);
typedef RpcHandler<I, O> = FutureOr<O> Function(RpcContext context, I input);
typedef RpcStreamHandler<I, O> =
    Stream<O> Function(RpcContext context, I input);
typedef RpcBeforeInvoke<I> =
    FutureOr<void> Function(RpcContext context, I input);

abstract interface class RegisteredRpcProcedure {
  String get method;
  ProcedureMetadata get metadata;
  RpcProcedureKind get kind;
  List<RpcGuard> get guards;
}

abstract interface class RpcCallableProcedure
    implements RegisteredRpcProcedure {
  @override
  RpcProcedureKind get kind => RpcProcedureKind.unary;

  Future<Object?> invoke(RpcContext context, Object? rawInput);
}

abstract interface class RpcCallableStreamProcedure
    implements RegisteredRpcProcedure {
  @override
  RpcProcedureKind get kind => RpcProcedureKind.serverStream;

  Stream<Object?> invokeStream(RpcContext context, Object? rawInput);
}

final class RpcUnaryProcedure<I, O> implements RpcCallableProcedure {
  const RpcUnaryProcedure({
    required this.method,
    required this.metadata,
    required this.decodeInput,
    required this.encodeOutput,
    required this.handler,
    this.guards = const [],
    this.beforeInvoke,
  });

  @override
  final String method;
  @override
  final ProcedureMetadata metadata;
  final RpcInputDecoder<I> decodeInput;
  final RpcOutputEncoder<O> encodeOutput;
  final RpcHandler<I, O> handler;
  @override
  final List<RpcGuard> guards;
  final RpcBeforeInvoke<I>? beforeInvoke;

  @override
  RpcProcedureKind get kind => RpcProcedureKind.unary;

  @override
  Future<Object?> invoke(RpcContext context, Object? rawInput) async {
    context.cancellation.throwIfCancelled();
    final input = _decode(rawInput);

    await runRpcGuards(
      guards,
      rpcContext: context,
      procedure: metadata,
      input: input,
    );

    context.cancellation.throwIfCancelled();
    await beforeInvoke?.call(context, input);
    context.cancellation.throwIfCancelled();
    final output = await handler(context, input);
    context.cancellation.throwIfCancelled();

    try {
      return encodeOutput(output);
    } on RpcException {
      rethrow;
    } catch (_) {
      throw RpcException.internalError(
        'Failed to encode RPC response for "$method".',
      );
    }
  }

  I _decode(Object? rawInput) {
    try {
      return decodeInput(rawInput);
    } on RpcException {
      rethrow;
    } catch (_) {
      throw RpcException.badRequest(
        'Failed to decode RPC input for "$method".',
      );
    }
  }
}

typedef RpcProcedure<I, O> = RpcUnaryProcedure<I, O>;

final class RpcStreamProcedure<I, O> implements RpcCallableStreamProcedure {
  const RpcStreamProcedure({
    required this.method,
    required this.metadata,
    required this.decodeInput,
    required this.encodeOutput,
    required this.handler,
    this.guards = const [],
    this.beforeInvoke,
  });

  @override
  final String method;
  @override
  final ProcedureMetadata metadata;
  final RpcInputDecoder<I> decodeInput;
  final RpcOutputEncoder<O> encodeOutput;
  final RpcStreamHandler<I, O> handler;
  @override
  final List<RpcGuard> guards;
  final RpcBeforeInvoke<I>? beforeInvoke;

  @override
  RpcProcedureKind get kind => RpcProcedureKind.serverStream;

  @override
  Stream<Object?> invokeStream(RpcContext context, Object? rawInput) {
    late StreamController<Object?> controller;
    StreamSubscription<O>? source;
    var consumerCancelled = false;
    var terminated = false;

    Future<void> close() async {
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    Future<void> fail(Object error, [StackTrace? stackTrace]) async {
      if (terminated || consumerCancelled) {
        return;
      }
      terminated = true;
      controller.addError(error, stackTrace);
      await source?.cancel();
      await close();
    }

    Future<void> cancelFromSignal() async {
      if (terminated || consumerCancelled) {
        return;
      }
      await fail(RpcException.cancelled());
    }

    Future<void> start() async {
      try {
        context.cancellation.throwIfCancelled();
        final input = _decode(rawInput);

        await runRpcGuards(
          guards,
          rpcContext: context,
          procedure: metadata,
          input: input,
        );

        context.cancellation.throwIfCancelled();
        await beforeInvoke?.call(context, input);
        context.cancellation.throwIfCancelled();
        if (consumerCancelled) {
          return;
        }

        source = handler(context, input).listen(
          (output) {
            if (terminated || consumerCancelled) {
              return;
            }
            try {
              context.cancellation.throwIfCancelled();
              controller.add(_encode(output));
            } on Object catch (error, stackTrace) {
              unawaited(fail(error, stackTrace));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            unawaited(fail(error, stackTrace));
          },
          onDone: () {
            if (!terminated && !consumerCancelled) {
              terminated = true;
              unawaited(close());
            }
          },
          cancelOnError: false,
        );
        if (consumerCancelled) {
          await source?.cancel();
        } else if (controller.isPaused) {
          source?.pause();
        }
      } on Object catch (error, stackTrace) {
        await fail(error, stackTrace);
      }
    }

    controller = StreamController<Object?>(
      onListen: () {
        if (!identical(context.cancellation, RpcCancellationSignal.none)) {
          unawaited(
            context.cancellation.cancelled.then((_) => cancelFromSignal()),
          );
        }
        unawaited(start());
      },
      onPause: () => source?.pause(),
      onResume: () => source?.resume(),
      onCancel: () async {
        consumerCancelled = true;
        terminated = true;
        await source?.cancel();
      },
    );
    return controller.stream;
  }

  I _decode(Object? rawInput) {
    try {
      return decodeInput(rawInput);
    } on RpcException {
      rethrow;
    } catch (_) {
      throw RpcException.badRequest(
        'Failed to decode RPC input for "$method".',
      );
    }
  }

  Object? _encode(O output) {
    try {
      return encodeOutput(output);
    } on RpcException {
      rethrow;
    } catch (_) {
      throw RpcException.internalError(
        'Failed to encode RPC stream event for "$method".',
      );
    }
  }
}

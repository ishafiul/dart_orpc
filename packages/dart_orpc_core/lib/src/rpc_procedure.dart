import 'dart:async';

import 'rpc_context.dart';
import 'rpc_exception.dart';

typedef RpcInputDecoder<I> = I Function(Object? rawInput);
typedef RpcOutputEncoder<O> = Object? Function(O output);
typedef RpcHandler<I, O> = FutureOr<O> Function(RpcContext context, I input);
typedef RpcBeforeInvoke<I> =
    FutureOr<void> Function(RpcContext context, I input);

abstract interface class RpcCallableProcedure {
  String get method;

  Future<Object?> invoke(RpcContext context, Object? rawInput);
}

final class RpcProcedure<I, O> implements RpcCallableProcedure {
  const RpcProcedure({
    required this.method,
    required this.decodeInput,
    required this.encodeOutput,
    required this.handler,
    this.beforeInvoke,
  });

  @override
  final String method;
  final RpcInputDecoder<I> decodeInput;
  final RpcOutputEncoder<O> encodeOutput;
  final RpcHandler<I, O> handler;
  final RpcBeforeInvoke<I>? beforeInvoke;

  @override
  Future<Object?> invoke(RpcContext context, Object? rawInput) async {
    final input = _decode(rawInput);
    await beforeInvoke?.call(context, input);
    final output = await handler(context, input);

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

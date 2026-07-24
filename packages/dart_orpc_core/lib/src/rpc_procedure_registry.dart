import 'rpc_context.dart';
import 'rpc_exception.dart';
import 'rpc_procedure.dart';
import 'rpc_request.dart';

final class RpcProcedureRegistry {
  RpcProcedureRegistry(Iterable<RegisteredRpcProcedure> procedures)
    : _procedures = _indexProcedures(procedures);

  final Map<String, RegisteredRpcProcedure> _procedures;

  Iterable<String> get methods => _procedures.keys;
  Iterable<RegisteredRpcProcedure> get procedures => _procedures.values;

  Future<Object?> dispatchUnary(RpcContext context, RpcRequest request) async {
    final procedure = _procedures[request.method];
    if (procedure == null) {
      throw _notFound(request.method);
    }
    if (procedure is! RpcCallableProcedure) {
      throw RpcException.badRequest(
        'RPC procedure "${request.method}" is a server stream.',
      );
    }

    return procedure.invoke(context, request.input);
  }

  Stream<Object?> dispatchStream(
    RpcContext context,
    RpcRequest request,
  ) async* {
    final procedure = _procedures[request.method];
    if (procedure == null) {
      throw _notFound(request.method);
    }
    if (procedure is! RpcCallableStreamProcedure) {
      throw RpcException.badRequest(
        'RPC procedure "${request.method}" is unary.',
      );
    }

    yield* procedure.invokeStream(context, request.input);
  }

  Future<Object?> dispatch(RpcContext context, RpcRequest request) {
    return dispatchUnary(context, request);
  }

  static RpcException _notFound(String method) {
    return RpcException.notFound('No RPC procedure registered for "$method".');
  }

  static Map<String, RegisteredRpcProcedure> _indexProcedures(
    Iterable<RegisteredRpcProcedure> procedures,
  ) {
    final indexed = <String, RegisteredRpcProcedure>{};

    for (final procedure in procedures) {
      if (indexed.containsKey(procedure.method)) {
        throw StateError('Duplicate RPC procedure "${procedure.method}".');
      }

      indexed[procedure.method] = procedure;
    }

    return Map.unmodifiable(indexed);
  }
}

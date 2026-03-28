import 'rpc_context.dart';
import 'rpc_exception.dart';
import 'rpc_procedure.dart';
import 'rpc_request.dart';

final class RpcProcedureRegistry {
  RpcProcedureRegistry(Iterable<RpcCallableProcedure> procedures)
    : _procedures = _indexProcedures(procedures);

  final Map<String, RpcCallableProcedure> _procedures;

  Iterable<String> get methods => _procedures.keys;
  Iterable<RpcCallableProcedure> get procedures => _procedures.values;

  Future<Object?> dispatch(RpcContext context, RpcRequest request) async {
    final procedure = _procedures[request.method];
    if (procedure == null) {
      throw RpcException.notFound(
        'No RPC procedure registered for "${request.method}".',
      );
    }

    return procedure.invoke(context, request.input);
  }

  static Map<String, RpcCallableProcedure> _indexProcedures(
    Iterable<RpcCallableProcedure> procedures,
  ) {
    final indexed = <String, RpcCallableProcedure>{};

    for (final procedure in procedures) {
      if (indexed.containsKey(procedure.method)) {
        throw StateError('Duplicate RPC procedure "${procedure.method}".');
      }

      indexed[procedure.method] = procedure;
    }

    return Map.unmodifiable(indexed);
  }
}

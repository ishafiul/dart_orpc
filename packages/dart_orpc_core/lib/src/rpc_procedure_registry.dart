import 'rpc_context.dart';
import 'rpc_exception.dart';
import 'procedure_metadata.dart';
import 'rpc_procedure.dart';
import 'rpc_request.dart';

final class RpcProcedureRegistry {
  RpcProcedureRegistry(Iterable<RegisteredRpcProcedure> procedures)
    : _procedures = _indexProcedures(procedures);

  final Map<String, _CompiledProcedure> _procedures;

  Iterable<String> get methods => _procedures.keys;
  Iterable<RegisteredRpcProcedure> get procedures =>
      _procedures.values.map((entry) => entry.procedure);

  Future<Object?> dispatchUnary(RpcContext context, RpcRequest request) async {
    final compiled = _procedures[request.method];
    if (compiled == null) {
      throw _notFound(request.method);
    }
    final procedure = compiled.procedure;
    if (procedure is! RpcCallableProcedure) {
      throw RpcException.badRequest(
        'RPC procedure "${request.method}" is a server stream.',
      );
    }

    return procedure.invoke(
      context,
      _bindHeaders(context, compiled.headerBindings, request.input),
    );
  }

  Stream<Object?> dispatchStream(
    RpcContext context,
    RpcRequest request,
  ) async* {
    final compiled = _procedures[request.method];
    if (compiled == null) {
      throw _notFound(request.method);
    }
    final procedure = compiled.procedure;
    if (procedure is! RpcCallableStreamProcedure) {
      throw RpcException.badRequest(
        'RPC procedure "${request.method}" is unary.',
      );
    }

    yield* procedure.invokeStream(
      context,
      _bindHeaders(context, compiled.headerBindings, request.input),
    );
  }

  Future<Object?> dispatch(RpcContext context, RpcRequest request) {
    return dispatchUnary(context, request);
  }

  static RpcException _notFound(String method) {
    return RpcException.notFound('No RPC procedure registered for "$method".');
  }

  static Object? _bindHeaders(
    RpcContext context,
    List<({String parameterName, String wireName})> headerBindings,
    Object? input,
  ) {
    if (headerBindings.isEmpty || input is! Map) return input;
    context.prepareHeaderLookup(headerBindings.length);
    final boundInput = <Object?, Object?>{...input};
    for (final binding in headerBindings) {
      final value = context.headerValue(binding.wireName);
      if (value != null) boundInput[binding.parameterName] = value;
    }
    return boundInput;
  }

  static Map<String, _CompiledProcedure> _indexProcedures(
    Iterable<RegisteredRpcProcedure> procedures,
  ) {
    final indexed = <String, _CompiledProcedure>{};

    for (final procedure in procedures) {
      if (indexed.containsKey(procedure.method)) {
        throw StateError('Duplicate RPC procedure "${procedure.method}".');
      }

      indexed[procedure.method] = _CompiledProcedure(procedure);
    }

    return Map.unmodifiable(indexed);
  }
}

final class _CompiledProcedure {
  _CompiledProcedure(this.procedure)
    : headerBindings = [
        for (final parameter in procedure.metadata.parameters)
          if (parameter.source == ProcedureParameterSourceKind.header)
            (
              parameterName: parameter.parameterName,
              wireName: parameter.wireName.toLowerCase(),
            ),
      ];
  final RegisteredRpcProcedure procedure;
  final List<({String parameterName, String wireName})> headerBindings;
}

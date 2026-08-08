import 'rpc_context.dart';
import 'rpc_exception.dart';
import 'procedure_metadata.dart';
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

    return procedure.invoke(
      context,
      _bindHeaders(context, procedure.metadata, request.input),
    );
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

    yield* procedure.invokeStream(
      context,
      _bindHeaders(context, procedure.metadata, request.input),
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
    ProcedureMetadata metadata,
    Object? input,
  ) {
    final headerParameters = metadata.parameters.where(
      (parameter) => parameter.source == ProcedureParameterSourceKind.header,
    );
    if (headerParameters.isEmpty) {
      return input;
    }

    if (input is! Map) {
      return input;
    }

    final boundInput = <Object?, Object?>{...input};
    for (final parameter in headerParameters) {
      final value = _headerValue(context.headers, parameter.wireName);
      if (value != null) {
        boundInput[parameter.parameterName] = value;
      }
    }
    return boundInput;
  }

  static String? _headerValue(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
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

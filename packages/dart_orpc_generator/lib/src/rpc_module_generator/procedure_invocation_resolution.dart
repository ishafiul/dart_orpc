part of '../rpc_module_generator.dart';

void _validateMethodSourceAnnotations(
  MethodElement method, {
  required String methodName,
  required _ResolvedPathMapping? path,
  required bool hasRestSourceParameters,
  required List<FormalParameterElement> rpcInputParameters,
  required List<FormalParameterElement> pathParameters,
  required List<FormalParameterElement> queryParameters,
}) {
  if (hasRestSourceParameters && path == null) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" may only use @PathParam, @QueryParam, or @Body when RpcMethod(path: ...) is declared.',
      element: method,
    );
  }
  if (path != null && rpcInputParameters.isNotEmpty && hasRestSourceParameters) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" may not mix @RpcInput with @PathParam, @QueryParam, or @Body.',
      element: method,
    );
  }

  _ensureUniqueWireNames(
    pathParameters,
    annotationLabel: '@PathParam',
    wireNameFor: _pathParamWireName,
    methodName: methodName,
  );
  _ensureUniqueWireNames(
    queryParameters,
    annotationLabel: '@QueryParam',
    wireNameFor: _queryParamWireName,
    methodName: methodName,
  );
  if (path != null && rpcInputParameters.isEmpty) {
    _validateRestPathBindings(
      path.path,
      pathParameters,
      methodName: methodName,
    );
  }
}

_ProcedureInvocationDetails _resolveProcedureInvocationDetails(
  MethodElement method, {
  required String methodName,
  required _ResolvedRestRpcInput? restRpcInput,
}) {
  final invocationArguments = <String>[];
  final restInvocationParameters = <_ResolvedInvocationParameter>[];
  final parameters = <_ResolvedParameter>[];
  var supportsRpcGeneration = true;

  for (final parameter in method.formalParameters) {
    final resolution = _resolveProcedureParameter(
      parameter,
      methodName: methodName,
      restRpcInput: restRpcInput,
    );
    supportsRpcGeneration &= resolution.supportsRpcGeneration;
    invocationArguments.add(resolution.invocationArgument);
    restInvocationParameters.add(resolution.restInvocationParameter);
    parameters.addAll(resolution.metadataParameters);
  }

  return _ProcedureInvocationDetails(
    invocationArguments: invocationArguments,
    restInvocationParameters: restInvocationParameters,
    parameters: parameters,
    supportsRpcGeneration: supportsRpcGeneration,
  );
}

final class _ProcedureInvocationDetails {
  const _ProcedureInvocationDetails({
    required this.invocationArguments,
    required this.restInvocationParameters,
    required this.parameters,
    required this.supportsRpcGeneration,
  });

  final List<String> invocationArguments;
  final List<_ResolvedInvocationParameter> restInvocationParameters;
  final List<_ResolvedParameter> parameters;
  final bool supportsRpcGeneration;
}

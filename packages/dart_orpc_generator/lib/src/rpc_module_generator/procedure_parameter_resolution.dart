part of '../rpc_module_generator.dart';

_ResolvedProcedureParameter _resolveProcedureParameter(
  FormalParameterElement parameter, {
  required String methodName,
  required _ResolvedRestRpcInput? restRpcInput,
}) {
  if (_isRpcContext(parameter.type)) {
    return const _ResolvedProcedureParameter.context();
  }
  if (_rpcInputChecker.hasAnnotationOfExact(parameter)) {
    return _ResolvedProcedureParameter.rpcInput(parameter, restRpcInput);
  }
  if (_pathParamChecker.hasAnnotationOfExact(parameter)) {
    _ensureSupportedRestScalarParameter(
      parameter,
      sourceLabel: '@PathParam',
      methodName: methodName,
    );
    return _ResolvedProcedureParameter.path(parameter);
  }
  if (_queryParamChecker.hasAnnotationOfExact(parameter)) {
    _ensureSupportedRestScalarParameter(
      parameter,
      sourceLabel: '@QueryParam',
      methodName: methodName,
    );
    return _ResolvedProcedureParameter.query(parameter);
  }
  if (_bodyChecker.hasAnnotationOfExact(parameter)) {
    return _ResolvedProcedureParameter.body(parameter);
  }
  throw InvalidGenerationSourceError(
    'RPC method "$methodName" only supports an optional RpcContext, one @RpcInput parameter, and explicit REST source parameters (@PathParam, @QueryParam, @Body).',
    element: parameter,
  );
}

final class _ResolvedProcedureParameter {
  const _ResolvedProcedureParameter({
    required this.invocationArgument,
    required this.restInvocationParameter,
    required this.metadataParameters,
    required this.supportsRpcGeneration,
  });

  const _ResolvedProcedureParameter.context()
    : this(
        invocationArgument: 'context',
        restInvocationParameter: const _ResolvedInvocationParameter(
          parameterName: 'context',
          source: _InvocationParameterSourceKind.context,
          typeCode: 'RpcContext',
          wireName: null,
          typeName: null,
          typeElement: null,
          usesLuthor: false,
        ),
        metadataParameters: const [],
        supportsRpcGeneration: true,
      );

  factory _ResolvedProcedureParameter.rpcInput(
    FormalParameterElement parameter,
    _ResolvedRestRpcInput? restRpcInput,
  ) {
    return _ResolvedProcedureParameter(
      invocationArgument: 'input',
      restInvocationParameter: _ResolvedInvocationParameter(
        parameterName: parameter.displayName,
        source: _InvocationParameterSourceKind.rpcInput,
        typeCode: parameter.type.getDisplayString(),
        wireName: parameter.displayName,
        typeName: parameter.type.element?.displayName,
        typeElement: parameter.type.element,
        usesLuthor: _usesLuthorValidation(parameter.type),
      ),
      metadataParameters: restRpcInput == null
          ? [
              _ResolvedParameter(
                parameterName: parameter.displayName,
                wireName: parameter.displayName,
                source: ProcedureParameterSourceKind.rpcInput,
                typeCode: parameter.type.getDisplayString(),
              ),
            ]
          : restRpcInput.metadataParameters,
      supportsRpcGeneration: true,
    );
  }

  factory _ResolvedProcedureParameter.path(FormalParameterElement parameter) {
    return _resolvedRestParameter(
      parameter,
      source: _InvocationParameterSourceKind.path,
      wireName: _pathParamWireName(parameter),
      metadataSource: ProcedureParameterSourceKind.path,
    );
  }

  factory _ResolvedProcedureParameter.query(FormalParameterElement parameter) {
    return _resolvedRestParameter(
      parameter,
      source: _InvocationParameterSourceKind.query,
      wireName: _queryParamWireName(parameter),
      metadataSource: ProcedureParameterSourceKind.query,
    );
  }

  factory _ResolvedProcedureParameter.body(FormalParameterElement parameter) {
    return _ResolvedProcedureParameter(
      invocationArgument: parameter.displayName,
      restInvocationParameter: _ResolvedInvocationParameter(
        parameterName: parameter.displayName,
        source: _InvocationParameterSourceKind.body,
        typeCode: parameter.type.getDisplayString(),
        wireName: parameter.displayName,
        typeName: parameter.type.element?.displayName,
        typeElement: parameter.type.element,
        usesLuthor: _usesLuthorValidation(parameter.type),
      ),
      metadataParameters: [
        _ResolvedParameter(
          parameterName: parameter.displayName,
          wireName: parameter.displayName,
          source: ProcedureParameterSourceKind.body,
          typeCode: parameter.type.getDisplayString(),
        ),
      ],
      supportsRpcGeneration: false,
    );
  }

  final String invocationArgument;
  final _ResolvedInvocationParameter restInvocationParameter;
  final List<_ResolvedParameter> metadataParameters;
  final bool supportsRpcGeneration;
}

_ResolvedProcedureParameter _resolvedRestParameter(
  FormalParameterElement parameter, {
  required _InvocationParameterSourceKind source,
  required String wireName,
  required ProcedureParameterSourceKind metadataSource,
}) {
  return _ResolvedProcedureParameter(
    invocationArgument: parameter.displayName,
    restInvocationParameter: _ResolvedInvocationParameter(
      parameterName: parameter.displayName,
      source: source,
      typeCode: parameter.type.getDisplayString(),
      wireName: wireName,
      typeName: parameter.type.element?.displayName,
      typeElement: parameter.type.element,
      usesLuthor: false,
    ),
    metadataParameters: [
      _ResolvedParameter(
        parameterName: parameter.displayName,
        wireName: wireName,
        source: metadataSource,
        typeCode: parameter.type.getDisplayString(),
      ),
    ],
    supportsRpcGeneration: false,
  );
}

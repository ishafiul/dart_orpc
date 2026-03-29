part of '../rpc_module_generator.dart';

_ResolvedProcedure _buildMethodBinding(String namespace, MethodElement method) {
  final methodAnnotation = _rpcMethodChecker.firstAnnotationOfExact(method);
  if (methodAnnotation == null) {
    throw InvalidGenerationSourceError(
      'RPC methods must be annotated with @RpcMethod.',
      element: method,
    );
  }

  final annotationReader = ConstantReader(methodAnnotation);
  final methodName = method.displayName;
  final path = _readPathMapping(annotationReader);
  final description = annotationReader.peek('description')?.stringValue;
  final tags = _readTags(annotationReader);
  final rpcInputParameters = method.formalParameters
      .where((parameter) => _rpcInputChecker.hasAnnotationOfExact(parameter))
      .toList(growable: false);
  final pathParameters = method.formalParameters
      .where((parameter) => _pathParamChecker.hasAnnotationOfExact(parameter))
      .toList(growable: false);
  final queryParameters = method.formalParameters
      .where((parameter) => _queryParamChecker.hasAnnotationOfExact(parameter))
      .toList(growable: false);
  final bodyParameters = method.formalParameters
      .where((parameter) => _bodyChecker.hasAnnotationOfExact(parameter))
      .toList(growable: false);

  if (rpcInputParameters.length > 1) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" may declare at most one @RpcInput parameter.',
      element: method,
    );
  }
  if (bodyParameters.length > 1) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" may declare at most one @Body parameter.',
      element: method,
    );
  }

  final hasRestSourceParameters =
      pathParameters.isNotEmpty ||
      queryParameters.isNotEmpty ||
      bodyParameters.isNotEmpty;
  _validateMethodSourceAnnotations(
    method,
    methodName: methodName,
    path: path,
    hasRestSourceParameters: hasRestSourceParameters,
    rpcInputParameters: rpcInputParameters,
    pathParameters: pathParameters,
    queryParameters: queryParameters,
  );

  final inputParameter = rpcInputParameters.isEmpty
      ? null
      : rpcInputParameters.single;
  final rpcInputBinding = inputParameter == null
      ? null
      : _readRpcInputBinding(inputParameter);
  if (rpcInputBinding != null && path == null) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" may only use @RpcInput(binding: ...) when RpcMethod(path: ...) is declared.',
      element: inputParameter,
    );
  }

  final restRpcInput =
      path != null && inputParameter != null && !hasRestSourceParameters
      ? _resolveRestRpcInput(
          inputParameter,
          path: path,
          methodName: methodName,
          binding: rpcInputBinding,
        )
      : null;
  final invocationDetails = _resolveProcedureInvocationDetails(
    method,
    methodName: methodName,
    restRpcInput: restRpcInput,
  );
  final outputType = _unwrapFuture(method.returnType);
  final wireName = annotationReader.peek('name')?.stringValue ?? methodName;

  return _ResolvedProcedure(
    controllerNamespace: namespace,
    methodName: methodName,
    rpcMethod: '$namespace.$wireName',
    path: path,
    description: description,
    tags: tags,
    parameters: invocationDetails.parameters,
    restInvocationParameters: invocationDetails.restInvocationParameters,
    restRpcInput: restRpcInput,
    hasInput: inputParameter != null,
    inputTypeCode: inputParameter?.type.getDisplayString(),
    inputTypeName: inputParameter?.type.element?.displayName,
    inputTypeElement: inputParameter?.type.element,
    inputParameterName: inputParameter?.displayName,
    inputUsesLuthor: inputParameter != null && _usesLuthorValidation(inputParameter.type),
    outputTypeCode: outputType.getDisplayString(),
    outputTypeName: outputType.element?.displayName ?? outputType.getDisplayString(),
    outputTypeElement: outputType.element,
    outputUsesLuthor: _usesLuthorValidation(outputType),
    supportsRpcGeneration: invocationDetails.supportsRpcGeneration,
    serverInvocationArguments: invocationDetails.invocationArguments.join(', '),
  );
}

_ResolvedPathMapping? _readPathMapping(ConstantReader annotationReader) {
  final pathReader = annotationReader.peek('path');
  if (pathReader == null || pathReader.isNull) {
    return null;
  }
  return _ResolvedPathMapping(
    method: pathReader.read('method').stringValue,
    path: _normalizeRestPath(pathReader.read('rawPath').stringValue),
  );
}

List<String> _readTags(ConstantReader annotationReader) {
  final tagsReader = annotationReader.peek('tags');
  if (tagsReader == null || tagsReader.isNull) {
    return const [];
  }
  return tagsReader.listValue
      .map((tag) => ConstantReader(tag).stringValue)
      .toList(growable: false);
}

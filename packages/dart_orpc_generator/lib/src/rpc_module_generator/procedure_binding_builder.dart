part of '../rpc_module_generator.dart';

_ResolvedProcedure _buildMethodBinding(
  String namespace,
  MethodElement method, {
  required Map<String, String> availableProviders,
  List<_ResolvedGuardBinding> inheritedGuardBindings = const [],
}) {
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
  final guardBindings = _mergeGuardBindings(
    inheritedGuardBindings,
    _resolveGuardBindings(
      method,
      availableProviders: availableProviders,
      ownerLabel:
          'method "${method.enclosingElement?.displayName ?? '<unknown>'}.${method.displayName}"',
    ),
  );
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
    guardBindings: guardBindings,
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
    inputUsesLuthor:
        inputParameter != null && _usesLuthorValidation(inputParameter.type),
    outputTypeCode: outputType.getDisplayString(),
    outputTypeName:
        outputType.element?.displayName ?? outputType.getDisplayString(),
    outputTypeElement: outputType.element,
    outputUsesLuthor: _usesLuthorValidation(outputType),
    supportsRpcGeneration: invocationDetails.supportsRpcGeneration,
    serverInvocationArguments: invocationDetails.invocationArguments.join(', '),
  );
}

List<_ResolvedGuardBinding> _resolveGuardBindings(
  Element element, {
  required Map<String, String> availableProviders,
  required String ownerLabel,
}) {
  final resolvedGuards = <_ResolvedGuardBinding>[];
  final seenTypeKeys = <String>{};

  for (final annotation in _useGuardsChecker.annotationsOfExact(element)) {
    final annotationReader = ConstantReader(annotation);
    for (final guardObject in annotationReader.read('guards').listValue) {
      final guardType = guardObject.toTypeValue();
      if (guardType is! InterfaceType) {
        throw InvalidGenerationSourceError(
          '$ownerLabel declares a @UseGuards entry that is not a class type.',
          element: element,
        );
      }
      if (!_rpcGuardChecker.isAssignableFromType(guardType)) {
        throw InvalidGenerationSourceError(
          '$ownerLabel declares "${guardType.element.displayName}" in @UseGuards, but it does not implement RpcGuard.',
          element: element,
        );
      }

      final typeKey = _typeKeyFor(guardType);
      if (!seenTypeKeys.add(typeKey)) {
        continue;
      }

      final variableName = availableProviders[typeKey];
      if (variableName == null) {
        throw InvalidGenerationSourceError(
          '$ownerLabel declares guard "${guardType.element.displayName}" in @UseGuards, but that guard is not available as a module provider or imported exported provider.',
          element: element,
        );
      }

      resolvedGuards.add(
        _ResolvedGuardBinding(
          typeKey: typeKey,
          typeName: guardType.element.displayName,
          variableName: variableName,
        ),
      );
    }
  }

  return resolvedGuards;
}

List<_ResolvedGuardBinding> _mergeGuardBindings(
  List<_ResolvedGuardBinding> inheritedGuardBindings,
  List<_ResolvedGuardBinding> localGuardBindings,
) {
  final merged = <_ResolvedGuardBinding>[];
  final seenTypeKeys = <String>{};

  for (final guardBinding in [
    ...inheritedGuardBindings,
    ...localGuardBindings,
  ]) {
    if (seenTypeKeys.add(guardBinding.typeKey)) {
      merged.add(guardBinding);
    }
  }

  return merged;
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

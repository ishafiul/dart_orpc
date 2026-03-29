part of '../rpc_module_generator.dart';

String _escapeDartString(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\$', r'\$');
}

String _normalizeRestPath(String rawPath) {
  if (rawPath.isEmpty) {
    return '/';
  }
  return rawPath.startsWith('/') ? rawPath : '/$rawPath';
}

String _decodeInputExpression(_ResolvedProcedure procedure) {
  if (!procedure.hasInput) {
    return '(rawInput) => expectNoRpcInput(rawInput, context: \'RPC method "${procedure.rpcMethod}"\')';
  }
  if (procedure.inputUsesLuthor) {
    return '(rawInput) => decodeRpcInputWithLuthor<${procedure.inputTypeCode!}>(rawInput: rawInput, method: \'${procedure.rpcMethod}\', validate: \$${procedure.inputTypeName!}Validate)';
  }
  return '(rawInput) => ${procedure.inputTypeCode!}.fromJson(Map<String, dynamic>.from(expectJsonObject(rawInput, context: \'RPC method "${procedure.rpcMethod}" input\')))';
}

String _encodeOutputExpression(_ResolvedProcedure procedure) {
  if (procedure.outputUsesLuthor) {
    return '(output) => encodeRpcOutputWithLuthor<${procedure.outputTypeCode}>(output: output, method: \'${procedure.rpcMethod}\', toJson: (output) => output.toJson(), validate: \$${procedure.outputTypeName}Validate)';
  }
  return '(output) => output.toJson()';
}

String? _restParameterDeclaration(
  _ResolvedInvocationParameter parameter,
  _ResolvedProcedure procedure,
) {
  final routeLabel = _restRouteLabel(procedure);
  return switch (parameter.source) {
    _InvocationParameterSourceKind.context => null,
    _InvocationParameterSourceKind.rpcInput => null,
    _InvocationParameterSourceKind.path =>
      'final ${parameter.parameterName} = decodeRestScalarParameter<${parameter.typeCode}>(rawValue: pathParameters[\'${parameter.wireName}\'], source: \'path parameter\', name: \'${parameter.wireName}\', route: \'$routeLabel\');',
    _InvocationParameterSourceKind.query =>
      'final ${parameter.parameterName} = decodeRestScalarParameter<${parameter.typeCode}>(rawValue: request.queryParameters[\'${parameter.wireName}\'], source: \'query parameter\', name: \'${parameter.wireName}\', route: \'$routeLabel\');',
    _InvocationParameterSourceKind.header =>
      'final ${parameter.parameterName} = decodeRestScalarParameter<${parameter.typeCode}>(rawValue: lookupRestHeader(request.headers, \'${_escapeDartString(parameter.wireName!)}\'), source: \'header\', name: \'${_escapeDartString(parameter.wireName!)}\', route: \'$routeLabel\');',
    _InvocationParameterSourceKind.body =>
      'final ${parameter.parameterName} = decodeRestBody<${parameter.typeCode}>(rawBody: request.body, route: \'$routeLabel\', parameterName: \'${parameter.parameterName}\', decode: ${_decodeRestBodyExpression(parameter, procedure)});',
  };
}

String _restInvocationArgumentExpression(_ResolvedInvocationParameter parameter) {
  return parameter.source == _InvocationParameterSourceKind.context
      ? 'context'
      : parameter.parameterName;
}

String _decodeRestBodyExpression(
  _ResolvedInvocationParameter parameter,
  _ResolvedProcedure procedure,
) {
  final routeLabel = _restRouteLabel(procedure);
  final bodyContext = '$routeLabel body';
  final nonNullableTypeCode = _nonNullableTypeCode(parameter.typeCode);
  if (_usesJsonObjectBodyDecode(nonNullableTypeCode)) {
    return "(rawBody) => expectJsonObject(rawBody, context: '$bodyContext')";
  }
  if (_isSupportedRestScalarType(parameter.typeCode)) {
    return "(rawBody) => decodeRestJsonValue<${parameter.typeCode}>(rawValue: rawBody, source: 'body parameter', name: '${parameter.parameterName}', route: '$routeLabel')";
  }
  if (parameter.usesLuthor) {
    return "(rawBody) => decodeRpcInputWithLuthor<${parameter.typeCode}>(rawInput: rawBody, method: '$bodyContext', validate: \$${parameter.typeName!}Validate)";
  }
  return "(rawBody) => ${parameter.typeName!}.fromJson(Map<String, dynamic>.from(expectJsonObject(rawBody, context: '$bodyContext')))";
}

String _restRouteLabel(_ResolvedProcedure procedure) {
  return '${procedure.path!.method} ${procedure.path!.path}';
}

List<String> _restRpcInputDeclarations(
  _ResolvedRestRpcInput restRpcInput,
  _ResolvedProcedure procedure,
) {
  final routeLabel = _restRouteLabel(procedure);
  final lines = <String>[];
  if (restRpcInput.mode == _ResolvedRestRpcInputMode.query) {
    lines.add('final rawInput = <String, Object?>{};');
  } else if (restRpcInput.bodyFields.isNotEmpty) {
    lines.add(
      "final rawInput = request.body.trim().isEmpty ? <String, Object?>{} : Map<String, Object?>.from(decodeRestBody<JsonObject>(rawBody: request.body, route: '$routeLabel', parameterName: '${restRpcInput.parameterName}', decode: (rawJson) => expectJsonObject(rawJson, context: '$routeLabel body')));",
    );
  } else {
    lines.add('final rawInput = <String, Object?>{};');
  }
  _appendRestRpcInputAssignments(lines, restRpcInput, routeLabel);
  lines.add('final ${restRpcInput.parameterName} = (${_decodeInputExpression(procedure)})(rawInput);');
  return lines;
}

void _appendRestRpcInputAssignments(
  List<String> lines,
  _ResolvedRestRpcInput restRpcInput,
  String routeLabel,
) {
  for (final pathField in restRpcInput.pathFields) {
    lines.add("rawInput['${pathField.name}'] = decodeRestScalarParameter<${pathField.typeCode}>(rawValue: pathParameters['${pathField.wireName}'], source: 'path parameter', name: '${pathField.wireName}', route: '$routeLabel');");
  }
  for (final queryField in restRpcInput.queryFields) {
    lines.add("rawInput['${queryField.name}'] = decodeRestScalarParameter<${queryField.typeCode}>(rawValue: request.queryParameters['${queryField.wireName}'], source: 'query parameter', name: '${queryField.wireName}', route: '$routeLabel');");
  }
  for (final headerField in restRpcInput.headerFields) {
    lines.add("rawInput['${headerField.name}'] = decodeRestScalarParameter<${headerField.typeCode}>(rawValue: lookupRestHeader(request.headers, '${_escapeDartString(headerField.wireName)}'), source: 'header', name: '${_escapeDartString(headerField.wireName)}', route: '$routeLabel');");
  }
}

void _ensureUniqueWireNames(
  List<FormalParameterElement> parameters, {
  required String annotationLabel,
  required String Function(FormalParameterElement parameter) wireNameFor,
  required String methodName,
}) {
  final seenWireNames = <String>{};
  for (final parameter in parameters) {
    final wireName = wireNameFor(parameter);
    if (!seenWireNames.add(wireName)) {
      throw InvalidGenerationSourceError(
        'RPC method "$methodName" declares duplicate $annotationLabel wire name "$wireName".',
        element: parameter,
      );
    }
  }
}

void _ensureSupportedRestScalarParameter(
  FormalParameterElement parameter, {
  required String sourceLabel,
  required String methodName,
}) {
  if (!_isSupportedRestScalarType(parameter.type.getDisplayString())) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" only supports String, int, double, or bool parameter types for $sourceLabel.',
      element: parameter,
    );
  }
}

void _validateRestPathBindings(
  String routePath,
  List<FormalParameterElement> pathParameters, {
  required String methodName,
}) {
  final routeParameters = RegExp(r':([A-Za-z_][A-Za-z0-9_]*)')
      .allMatches(routePath)
      .map((match) => match.group(1)!)
      .toSet();
  final boundParameters = pathParameters.map(_pathParamWireName).toSet();
  final unknownBindings = boundParameters.difference(routeParameters);
  if (unknownBindings.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" declares @PathParam bindings not present in route "$routePath": ${unknownBindings.join(', ')}.',
    );
  }
  final missingBindings = routeParameters.difference(boundParameters);
  if (missingBindings.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" must declare @PathParam bindings for route "$routePath": ${missingBindings.join(', ')}.',
    );
  }
}

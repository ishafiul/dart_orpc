part of '../../rpc_module_generator.dart';

String _escapeDartString(String value) {
  return value
      .replaceAll('\\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\$', r'\$');
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

/// The encoder every transport uses for this procedure's output: RPC, REST,
/// streams and WebSocket all share it, so their JSON cannot differ.
String _encodeOutputExpression(_ResolvedProcedure procedure) {
  if (procedure.outputCodecKind == _OutputCodecKind.voidValue) {
    return '(_) => null';
  }
  return '(output) => ${_encodedOutput(procedure, 'output')}';
}

/// The expression that encodes [variable], decided at generation time.
String _encodedOutput(_ResolvedProcedure procedure, String variable) {
  if (procedure.outputCodecKind == _OutputCodecKind.voidValue) {
    return 'null';
  }
  if (procedure.outputCodecKind == _OutputCodecKind.jsonValue) {
    return variable;
  }
  if (procedure.outputUsesLuthor) {
    return 'encodeRpcOutputJsonWithLuthor<${procedure.outputTypeCode}>(output: $variable, method: \'${procedure.rpcMethod}\', toJson: (output) => output.toJson(), validateJson: \$${procedure.outputTypeName}Schema.validate)';
  }
  if (procedure.outputIsJsonBytes) {
    return variable;
  }
  return '$variable.toJson()';
}

String _serverHandlerExpression(
  _ResolvedProcedure procedure,
  String invocationExpression,
) {
  if (!procedure.isVoid) {
    return '(context, input) => $invocationExpression';
  }
  final invocation = procedure.returnsFuture
      ? 'await $invocationExpression;'
      : '$invocationExpression;';
  final asyncModifier = procedure.returnsFuture ? 'async ' : '';
  return '(context, input) $asyncModifier{ $invocation return null; }';
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

String _restInvocationArgumentExpression(
  _ResolvedInvocationParameter parameter,
) {
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
    return "(rawBody) => decodeRestJsonValue<${parameter.typeCode}>(rawValue: rawBody, source: 'body parameter', name: '${parameter.parameterName}', issuePath: const [], route: '$routeLabel')";
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
      "final rawInput = decodeRestRpcInputBody(request, route: '$routeLabel', parameterName: '${restRpcInput.parameterName}');",
    );
  } else {
    lines.add('final rawInput = <String, Object?>{};');
  }
  _appendRestRpcInputAssignments(lines, restRpcInput, routeLabel);
  lines.add(
    'final ${restRpcInput.parameterName} = (${_decodeInputExpression(procedure)})(rawInput);',
  );
  return lines;
}

void _appendRestRpcInputAssignments(
  List<String> lines,
  _ResolvedRestRpcInput restRpcInput,
  String routeLabel,
) {
  for (final pathField in restRpcInput.pathFields) {
    lines.add(
      "rawInput['${pathField.name}'] = decodeRestScalarParameter<${pathField.typeCode}>(rawValue: pathParameters['${pathField.wireName}'], source: 'path parameter', name: '${pathField.wireName}',${_inputKeyArgument(pathField)} route: '$routeLabel');",
    );
  }
  for (final queryField in restRpcInput.queryFields) {
    lines.add(
      "rawInput['${queryField.name}'] = decodeRestScalarParameter<${queryField.typeCode}>(rawValue: request.queryParameters['${queryField.wireName}'], source: 'query parameter', name: '${queryField.wireName}',${_inputKeyArgument(queryField)} route: '$routeLabel');",
    );
  }
  for (final headerField in restRpcInput.headerFields) {
    lines.add(
      "rawInput['${headerField.name}'] = decodeRestScalarParameter<${headerField.typeCode}>(rawValue: lookupRestHeader(request.headers, '${_escapeDartString(headerField.wireName)}'), source: 'header', name: '${_escapeDartString(headerField.wireName)}',${_inputKeyArgument(headerField)} route: '$routeLabel');",
    );
  }
}

/// The `inputKey:` argument naming the DTO JSON key a REST value fills, so
/// its validation issue uses that key; empty when the wire name is the key.
String _inputKeyArgument(_ResolvedRestInputField field) =>
    field.jsonKey == field.wireName
    ? ''
    : " inputKey: '${_escapeDartString(field.jsonKey)}',";

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
  RestRoutePattern route,
  List<FormalParameterElement> pathParameters, {
  required String methodName,
}) {
  final routeParameters = route.parameterNames.toSet();
  final boundParameters = pathParameters.map(_pathParamWireName).toSet();
  final unknownBindings = boundParameters.difference(routeParameters);
  if (unknownBindings.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" declares @PathParam bindings not present in route "${route.path}": ${unknownBindings.join(', ')}.',
    );
  }
  final missingBindings = routeParameters.difference(boundParameters);
  if (missingBindings.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'RPC method "$methodName" must declare @PathParam bindings for route "${route.path}": ${missingBindings.join(', ')}.',
    );
  }
}

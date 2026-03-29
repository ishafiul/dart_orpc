part of '../rpc_module_generator.dart';

_ResolvedRestRpcInput _resolveRestRpcInput(
  FormalParameterElement inputParameter, {
  required _ResolvedPathMapping path,
  required String methodName,
  _ResolvedRpcInputDetails? binding,
}) {
  final inputFields = _resolveDtoFields(
    inputParameter.type,
    methodName: methodName,
  );
  if (inputFields.isEmpty) {
    throw InvalidGenerationSourceError(
      'REST-enabled RPC method "$methodName" could not infer fields from input DTO "${inputParameter.type.getDisplayString()}".',
      element: inputParameter,
    );
  }

  final fieldByName = {for (final field in inputFields) field.name: field};
  final routeParameters = RegExp(r':([A-Za-z_][A-Za-z0-9_]*)')
      .allMatches(path.path)
      .map((match) => match.group(1)!)
      .toList(growable: false);
  final effectiveDetails = _mergeRpcInputDetails(
    _rpcInputBindingFromDtoFields(inputFields),
    binding,
  );
  _validateRpcInputDetails(
    effectiveDetails,
    fieldByName: fieldByName,
    routeParameters: routeParameters,
    methodName: methodName,
    element: inputParameter,
  );

  final explicitSourceByField = <String, _ResolvedRpcInputField>{
    for (final binding in [
      ...effectiveDetails.path,
      ...effectiveDetails.query,
      ...effectiveDetails.headers,
      ...effectiveDetails.body,
    ])
      binding.fieldName: binding,
  };
  final pathFields = _resolveRestPathFields(
    routeParameters,
    path: path,
    fieldByName: fieldByName,
    explicitSourceByField: explicitSourceByField,
    effectiveDetails: effectiveDetails,
    methodName: methodName,
    inputParameter: inputParameter,
  );
  final queryFields = _resolveRestInputFieldBindings(
    effectiveDetails.query,
    fieldByName: fieldByName,
    sourceLabel: 'query parameter',
    methodName: methodName,
    element: inputParameter,
  );
  final headerFields = _resolveRestInputFieldBindings(
    effectiveDetails.headers,
    fieldByName: fieldByName,
    sourceLabel: 'header',
    methodName: methodName,
    element: inputParameter,
  );
  final explicitBodyFields = _resolveRestInputFieldBindings(
    effectiveDetails.body,
    fieldByName: fieldByName,
    sourceLabel: 'body',
    methodName: methodName,
    element: inputParameter,
    allowCustomWireName: false,
    requiresScalar: false,
  );

  final boundFieldNames = {
    ...pathFields.map((field) => field.name),
    ...queryFields.map((field) => field.name),
    ...headerFields.map((field) => field.name),
    ...explicitBodyFields.map((field) => field.name),
  };
  final remainingFields = inputFields
      .where((field) => !boundFieldNames.contains(field.name))
      .toList(growable: false);

  return _buildResolvedRestRpcInput(
    inputParameter,
    path: path,
    methodName: methodName,
    pathFields: pathFields,
    queryFields: queryFields,
    headerFields: headerFields,
    explicitBodyFields: explicitBodyFields,
    remainingFields: remainingFields,
  );
}

List<_ResolvedRestInputField> _resolveRestPathFields(
  List<String> routeParameters, {
  required _ResolvedPathMapping path,
  required Map<String, _ResolvedDtoField> fieldByName,
  required Map<String, _ResolvedRpcInputField> explicitSourceByField,
  required _ResolvedRpcInputDetails effectiveDetails,
  required String methodName,
  required FormalParameterElement inputParameter,
}) {
  final explicitPathByWireName = {
    for (final binding in effectiveDetails.path) binding.wireName: binding,
  };
  final pathFields = <_ResolvedRestInputField>[];
  for (final routeParameter in routeParameters) {
    final explicitPathBinding = explicitPathByWireName[routeParameter];
    if (explicitPathBinding != null) {
      pathFields.add(
        _resolvePathFieldFromBinding(
          explicitPathBinding,
          fieldByName: fieldByName,
          methodName: methodName,
          element: inputParameter,
        ),
      );
      continue;
    }

    final conflictingBinding = explicitSourceByField[routeParameter];
    if (conflictingBinding != null && conflictingBinding.source != 'path') {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" binds DTO field "$routeParameter" from ${conflictingBinding.source}, but route "${path.path}" requires it as a path parameter.',
        element: inputParameter,
      );
    }
    final field = fieldByName[routeParameter];
    if (field == null) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" must declare input DTO field "$routeParameter" required by route "${path.path}".',
        element: inputParameter,
      );
    }
    _ensureSupportedRestInputField(
      field,
      sourceLabel: 'path parameter',
      methodName: methodName,
      element: inputParameter,
    );
    pathFields.add(
      _ResolvedRestInputField(
        name: field.name,
        typeCode: field.typeCode,
        wireName: routeParameter,
      ),
    );
  }
  return pathFields;
}

List<_ResolvedRestInputField> _resolveRestInputFieldBindings(
  List<_ResolvedRpcInputField> bindings, {
  required Map<String, _ResolvedDtoField> fieldByName,
  required String sourceLabel,
  required String methodName,
  required Element element,
  bool allowCustomWireName = true,
  bool requiresScalar = true,
}) {
  return [
    for (final binding in bindings)
      _resolveRestInputFieldBinding(
        binding,
        fieldByName: fieldByName,
        sourceLabel: sourceLabel,
        methodName: methodName,
        element: element,
        allowCustomWireName: allowCustomWireName,
        requiresScalar: requiresScalar,
      ),
  ];
}

part of '../rpc_module_generator.dart';

_ResolvedRestRpcInput _buildResolvedRestRpcInput(
  FormalParameterElement inputParameter, {
  required _ResolvedPathMapping path,
  required String methodName,
  required List<_ResolvedRestInputField> pathFields,
  required List<_ResolvedRestInputField> queryFields,
  required List<_ResolvedRestInputField> headerFields,
  required List<_ResolvedRestInputField> explicitBodyFields,
  required List<_ResolvedDtoField> remainingFields,
}) {
  final httpMethod = path.method.toUpperCase();
  if (httpMethod == 'GET' || httpMethod == 'DELETE') {
    if (explicitBodyFields.isNotEmpty) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" may not bind @RpcInput(binding: ...) body fields for ${path.method} routes.',
        element: inputParameter,
      );
    }
    for (final field in remainingFields) {
      _ensureSupportedRestInputField(
        field,
        sourceLabel: 'query parameter',
        methodName: methodName,
        element: inputParameter,
      );
    }
    final inferredQueryFields = [
      ...queryFields,
      for (final field in remainingFields)
        _ResolvedRestInputField(
          name: field.name,
          typeCode: field.typeCode,
          wireName: field.name,
        ),
    ];
    return _ResolvedRestRpcInput(
      parameterName: inputParameter.displayName,
      mode: _ResolvedRestRpcInputMode.query,
      pathFields: pathFields,
      queryFields: inferredQueryFields,
      headerFields: headerFields,
      bodyFields: const [],
      metadataParameters: _buildRestMetadataParameters(
        inputParameter.displayName,
        pathFields: pathFields,
        queryFields: inferredQueryFields,
        headerFields: headerFields,
        includeBody: false,
        bodyTypeCode: inputParameter.type.getDisplayString(),
      ),
    );
  }

  final bodyFields = [
    ...explicitBodyFields,
    for (final field in remainingFields)
      _ResolvedRestInputField(
        name: field.name,
        typeCode: field.typeCode,
        wireName: field.name,
      ),
  ];
  return _ResolvedRestRpcInput(
    parameterName: inputParameter.displayName,
    mode: _ResolvedRestRpcInputMode.body,
    pathFields: pathFields,
    queryFields: queryFields,
    headerFields: headerFields,
    bodyFields: bodyFields,
    metadataParameters: _buildRestMetadataParameters(
      inputParameter.displayName,
      pathFields: pathFields,
      queryFields: queryFields,
      headerFields: headerFields,
      includeBody: bodyFields.isNotEmpty,
      bodyTypeCode: inputParameter.type.getDisplayString(),
    ),
  );
}

List<_ResolvedParameter> _buildRestMetadataParameters(
  String parameterName, {
  required List<_ResolvedRestInputField> pathFields,
  required List<_ResolvedRestInputField> queryFields,
  required List<_ResolvedRestInputField> headerFields,
  required bool includeBody,
  required String bodyTypeCode,
}) {
  return [
    for (final field in pathFields)
      _ResolvedParameter(
        parameterName: field.name,
        wireName: field.wireName,
        source: ProcedureParameterSourceKind.path,
        typeCode: field.typeCode,
      ),
    for (final field in queryFields)
      _ResolvedParameter(
        parameterName: field.name,
        wireName: field.wireName,
        source: ProcedureParameterSourceKind.query,
        typeCode: field.typeCode,
      ),
    for (final field in headerFields)
      _ResolvedParameter(
        parameterName: field.name,
        wireName: field.wireName,
        source: ProcedureParameterSourceKind.header,
        typeCode: field.typeCode,
      ),
    if (includeBody)
      _ResolvedParameter(
        parameterName: parameterName,
        wireName: parameterName,
        source: ProcedureParameterSourceKind.body,
        typeCode: bodyTypeCode,
      ),
  ];
}

part of '../rpc_module_generator.dart';

_ResolvedRpcInputDetails? _readRpcInputBinding(
  FormalParameterElement parameter,
) {
  final annotation = _rpcInputChecker.firstAnnotationOfExact(parameter);
  if (annotation == null) {
    return null;
  }
  final bindingReader = ConstantReader(annotation).peek('binding');
  if (bindingReader == null || bindingReader.isNull) {
    return null;
  }

  return _ResolvedRpcInputDetails(
    path: _readRpcInputFieldBindings(bindingReader.read('path'), source: 'path'),
    query: _readRpcInputFieldBindings(bindingReader.read('query'), source: 'query'),
    headers: _readRpcInputFieldBindings(bindingReader.read('headers'), source: 'header'),
    body: _readRpcInputFieldBindings(bindingReader.read('body'), source: 'body'),
  );
}

List<_ResolvedRpcInputField> _readRpcInputFieldBindings(
  ConstantReader reader, {
  required String source,
}) {
  if (reader.isNull) {
    return const [];
  }
  return reader.listValue
      .map((value) {
        final bindingReader = ConstantReader(value);
        final fieldName = bindingReader.read('field').stringValue;
        return _ResolvedRpcInputField(
          fieldName: fieldName,
          wireName: bindingReader.peek('name')?.stringValue ?? fieldName,
          source: source,
        );
      })
      .toList(growable: false);
}

_ResolvedRpcInputDetails _rpcInputBindingFromDtoFields(
  List<_ResolvedDtoField> inputFields,
) {
  List<_ResolvedRpcInputField> build(String source) => [
    for (final field in inputFields)
      if (field.defaultSource == source)
        _ResolvedRpcInputField(
          fieldName: field.name,
          wireName: field.defaultWireName ?? field.name,
          source: source,
        ),
  ];

  return _ResolvedRpcInputDetails(
    path: build('path'),
    query: build('query'),
    headers: build('header'),
    body: const [],
  );
}

_ResolvedRpcInputDetails _mergeRpcInputDetails(
  _ResolvedRpcInputDetails defaults,
  _ResolvedRpcInputDetails? overrides,
) {
  if (overrides == null) {
    return defaults;
  }
  final overriddenFields = <String>{
    for (final binding in [
      ...overrides.path,
      ...overrides.query,
      ...overrides.headers,
      ...overrides.body,
    ])
      binding.fieldName,
  };
  List<_ResolvedRpcInputField> merge(
    List<_ResolvedRpcInputField> defaultBindings,
    List<_ResolvedRpcInputField> overrideBindings,
  ) {
    return [
      for (final binding in defaultBindings)
        if (!overriddenFields.contains(binding.fieldName)) binding,
      ...overrideBindings,
    ];
  }

  return _ResolvedRpcInputDetails(
    path: merge(defaults.path, overrides.path),
    query: merge(defaults.query, overrides.query),
    headers: merge(defaults.headers, overrides.headers),
    body: merge(defaults.body, overrides.body),
  );
}

void _validateRpcInputDetails(
  _ResolvedRpcInputDetails details, {
  required Map<String, _ResolvedDtoField> fieldByName,
  required List<String> routeParameters,
  required String methodName,
  required Element element,
}) {
  final boundFieldNames = <String>{};
  for (final binding in [
    ...details.path,
    ...details.query,
    ...details.headers,
    ...details.body,
  ]) {
    if (!fieldByName.containsKey(binding.fieldName)) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" references unknown DTO field "${binding.fieldName}" in @RpcInput(binding: ...).',
        element: element,
      );
    }
    if (!boundFieldNames.add(binding.fieldName)) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" may not bind DTO field "${binding.fieldName}" from more than one @RpcInput(binding: ...) source.',
        element: element,
      );
    }
  }

  _ensureUniqueRpcInputDetailWireNames(details.path, sourceLabel: 'path', methodName: methodName, element: element);
  _ensureUniqueRpcInputDetailWireNames(details.query, sourceLabel: 'query', methodName: methodName, element: element);
  _ensureUniqueRpcInputDetailWireNames(details.headers, sourceLabel: 'header', methodName: methodName, element: element);

  final routeParameterSet = routeParameters.toSet();
  final unknownPathBindings = details.path
      .where((binding) => !routeParameterSet.contains(binding.wireName))
      .toList(growable: false);
  if (unknownPathBindings.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'REST-enabled RPC method "$methodName" declares @RpcInput(binding: ...) path bindings not present in route: ${unknownPathBindings.map((binding) => binding.wireName).join(', ')}.',
      element: element,
    );
  }

  final invalidBodyBindings = details.body
      .where((binding) => binding.wireName != binding.fieldName)
      .toList(growable: false);
  if (invalidBodyBindings.isNotEmpty) {
    throw InvalidGenerationSourceError(
      'REST-enabled RPC method "$methodName" does not support custom body wire names in @RpcInput(binding: ...).',
      element: element,
    );
  }
}

void _ensureUniqueRpcInputDetailWireNames(
  List<_ResolvedRpcInputField> bindings, {
  required String sourceLabel,
  required String methodName,
  required Element element,
}) {
  final seenWireNames = <String>{};
  for (final binding in bindings) {
    if (!seenWireNames.add(binding.wireName)) {
      throw InvalidGenerationSourceError(
        'REST-enabled RPC method "$methodName" declares duplicate $sourceLabel binding "${binding.wireName}" in @RpcInput(binding: ...).',
        element: element,
      );
    }
  }
}

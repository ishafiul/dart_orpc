part of '../rpc_module_generator.dart';

_ResolvedRestInputField _resolvePathFieldFromBinding(
  _ResolvedRpcInputField binding, {
  required Map<String, _ResolvedDtoField> fieldByName,
  required String methodName,
  required Element element,
}) {
  return _resolveRestInputFieldBinding(
    binding,
    fieldByName: fieldByName,
    sourceLabel: 'path parameter',
    methodName: methodName,
    element: element,
  );
}

_ResolvedRestInputField _resolveRestInputFieldBinding(
  _ResolvedRpcInputField binding, {
  required Map<String, _ResolvedDtoField> fieldByName,
  required String sourceLabel,
  required String methodName,
  required Element element,
  bool allowCustomWireName = true,
  bool requiresScalar = true,
}) {
  final field = fieldByName[binding.fieldName]!;
  if (requiresScalar) {
    _ensureSupportedRestInputField(
      field,
      sourceLabel: sourceLabel,
      methodName: methodName,
      element: element,
    );
  }
  if (!allowCustomWireName && binding.wireName != binding.fieldName) {
    throw InvalidGenerationSourceError(
      'REST-enabled RPC method "$methodName" does not support custom $sourceLabel names for DTO field "${binding.fieldName}".',
      element: element,
    );
  }
  return _ResolvedRestInputField(
    name: field.name,
    typeCode: field.typeCode,
    wireName: binding.wireName,
  );
}

void _ensureSupportedRestInputField(
  _ResolvedDtoField field, {
  required String sourceLabel,
  required String methodName,
  required Element element,
}) {
  if (_isSupportedRestScalarType(field.typeCode)) {
    return;
  }
  throw InvalidGenerationSourceError(
    'REST-enabled RPC method "$methodName" only supports String, int, double, or bool input DTO fields for $sourceLabel binding. Unsupported field: "${field.name}".',
    element: element,
  );
}

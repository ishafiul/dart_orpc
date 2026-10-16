part of '../../rpc_module_generator.dart';

List<_ResolvedDtoField> _resolveDtoFields(
  DartType type, {
  required String methodName,
}) {
  final element = type.element;
  if (element is! InterfaceElement) {
    throw InvalidGenerationSourceError(
      'REST-enabled RPC method "$methodName" requires an interface or class DTO input type.',
    );
  }

  final fieldsByName = <String, _ResolvedDtoFieldBuilder>{};
  for (final candidate in [
    ...discoverDtoMembers(element),
    ...discoverDtoConstructorParameters(element),
  ]) {
    final field = fieldsByName.putIfAbsent(
      candidate.name,
      () => _ResolvedDtoFieldBuilder(
        name: candidate.name,
        typeCode: candidate.type.getDisplayString(),
      ),
    );
    final binding = _readResolvedDtoFieldBinding(
      candidate.element,
      methodName: methodName,
    );
    if (binding != null) {
      field.applyBinding(binding, methodName: methodName, element: element);
    }
  }

  return fieldsByName.values
      .map((field) => field.build())
      .toList(growable: false);
}

_ResolvedDtoFieldBinding? _readResolvedDtoFieldBinding(
  Element element, {
  required String methodName,
}) {
  final bindings = <_ResolvedDtoFieldBinding>[];
  _appendDtoFieldBinding(
    bindings,
    element,
    checker: _fromPathChecker,
    source: 'path',
  );
  _appendDtoFieldBinding(
    bindings,
    element,
    checker: _fromQueryChecker,
    source: 'query',
  );
  _appendDtoFieldBinding(
    bindings,
    element,
    checker: _fromHeaderChecker,
    source: 'header',
  );

  if (bindings.length > 1) {
    throw InvalidGenerationSourceError(
      'RPC DTO field "${element.displayName}" may declare at most one of @FromPath, @FromQuery, or @FromHeader.',
      element: element,
    );
  }
  return bindings.isEmpty ? null : bindings.single;
}

void _appendDtoFieldBinding(
  List<_ResolvedDtoFieldBinding> bindings,
  Element element, {
  required TypeChecker checker,
  required String source,
}) {
  final annotation = checker.firstAnnotationOfExact(element);
  if (annotation == null) {
    return;
  }
  bindings.add(
    _ResolvedDtoFieldBinding(
      source: source,
      wireName: ConstantReader(annotation).peek('name')?.stringValue,
    ),
  );
}

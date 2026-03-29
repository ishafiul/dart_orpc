part of '../rpc_module_generator.dart';

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
  void recordField(String name, String typeCode, {_ResolvedDtoFieldBinding? binding}) {
    final field = fieldsByName.putIfAbsent(
      name,
      () => _ResolvedDtoFieldBuilder(name: name, typeCode: typeCode),
    );
    if (binding != null) {
      field.applyBinding(binding, methodName: methodName, element: element);
    }
  }

  for (final field in element.fields) {
    final name = field.displayName;
    if (!field.isStatic && !name.startsWith('_')) {
      recordField(
        name,
        field.type.getDisplayString(),
        binding: _readResolvedDtoFieldBinding(field, methodName: methodName),
      );
    }
  }

  for (final getter in element.getters) {
    final name = getter.displayName;
    if (!getter.isStatic &&
        !name.startsWith('_') &&
        name != 'hashCode' &&
        name != 'runtimeType') {
      recordField(
        name,
        getter.returnType.getDisplayString(),
        binding: _readResolvedDtoFieldBinding(getter, methodName: methodName),
      );
    }
  }

  for (final constructor in element.constructors.where((constructor) {
    final name = constructor.name ?? '';
    return name.isEmpty || name == 'new';
  })) {
    for (final parameter in constructor.formalParameters) {
      if (!parameter.displayName.startsWith('_')) {
        recordField(
          parameter.displayName,
          parameter.type.getDisplayString(),
          binding: _readResolvedDtoFieldBinding(
            parameter,
            methodName: methodName,
          ),
        );
      }
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
  _appendDtoFieldBinding(bindings, element, checker: _fromPathChecker, source: 'path');
  _appendDtoFieldBinding(bindings, element, checker: _fromQueryChecker, source: 'query');
  _appendDtoFieldBinding(bindings, element, checker: _fromHeaderChecker, source: 'header');

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

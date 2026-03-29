part of '../rpc_module_generator.dart';

String _pathParamWireName(FormalParameterElement parameter) {
  final annotation = _pathParamChecker.firstAnnotationOfExact(parameter);
  if (annotation == null) {
    return parameter.displayName;
  }
  return ConstantReader(annotation).peek('name')?.stringValue ??
      parameter.displayName;
}

String _queryParamWireName(FormalParameterElement parameter) {
  final annotation = _queryParamChecker.firstAnnotationOfExact(parameter);
  if (annotation == null) {
    return parameter.displayName;
  }
  return ConstantReader(annotation).peek('name')?.stringValue ??
      parameter.displayName;
}

bool _isSupportedRestScalarType(String typeCode) {
  return switch (_nonNullableTypeCode(typeCode)) {
    'String' || 'int' || 'double' || 'bool' => true,
    _ => false,
  };
}

bool _usesJsonObjectBodyDecode(String typeCode) {
  return typeCode == 'JsonObject' || typeCode.startsWith('Map<');
}

String _nonNullableTypeCode(String typeCode) {
  return typeCode.endsWith('?')
      ? typeCode.substring(0, typeCode.length - 1)
      : typeCode;
}

_ResolvedInstantiation? _tryBuildInstantiation(
  InterfaceElement element, {
  required Map<String, String> availableProviders,
  required Set<String> usedNames,
}) {
  final constructor = _selectUnnamedConstructor(element);
  final positionalArguments = <String>[];
  final namedArguments = <String>[];

  for (final parameter in constructor.formalParameters) {
    final dependency = availableProviders[_typeKeyFor(parameter.type)];
    if (dependency == null) {
      return null;
    }
    if (parameter.isNamed) {
      namedArguments.add('${parameter.name}: $dependency');
    } else {
      positionalArguments.add(dependency);
    }
  }

  final variableName = _uniqueName(_lowerCamel(element.displayName), usedNames);
  return _ResolvedInstantiation(
    typeKey: _typeKeyFor(element.thisType),
    typeName: element.displayName,
    variableName: variableName,
    providerElement: element,
    code:
        'final $variableName = ${element.displayName}(${[...positionalArguments, ...namedArguments].join(', ')});',
  );
}

ConstructorElement _selectUnnamedConstructor(InterfaceElement element) {
  final constructors = element.constructors
      .where((constructor) => !constructor.isFactory)
      .toList(growable: false);
  if (constructors.isEmpty) {
    throw InvalidGenerationSourceError(
      'Type "${element.displayName}" must declare an unnamed constructor.',
      element: element,
    );
  }

  final unnamedConstructors = constructors
      .where((constructor) {
        final name = constructor.name ?? '';
        return name.isEmpty || name == 'new';
      })
      .toList(growable: false);
  if (unnamedConstructors.length != 1) {
    throw InvalidGenerationSourceError(
      'Type "${element.displayName}" must declare exactly one unnamed constructor.',
      element: element,
    );
  }
  return unnamedConstructors.single;
}

DartType _unwrapFuture(DartType type) {
  if (type is InterfaceType &&
      type.element.name == 'Future' &&
      type.typeArguments.length == 1) {
    return type.typeArguments.single;
  }
  return type;
}

bool _isRpcContext(DartType type) => _rpcContextChecker.isExactlyType(type);

bool _usesLuthorValidation(DartType type) {
  final element = type.element;
  return element is InterfaceElement && _luthorChecker.hasAnnotationOfExact(element);
}

String _typeKeyFor(DartType type) => type.getDisplayString();

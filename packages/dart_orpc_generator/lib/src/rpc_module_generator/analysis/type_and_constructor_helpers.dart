part of '../../rpc_module_generator.dart';

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
  _ProviderDefinition provider, {
  required Map<String, String> availableProviders,
  required Set<String> usedNames,
  String? forcedVariableName,
}) {
  final positionalArguments = <String>[];
  final namedArguments = <String>[];
  var optionalPositionalGap = false;

  for (final parameter in provider.parameters) {
    final dependency =
        availableProviders[_dependencyTypeKeyFor(parameter.type)];
    if (dependency == null) {
      if (!parameter.isOptional) return null;
      if (parameter.isOptionalPositional) optionalPositionalGap = true;
      continue;
    }
    if (parameter.isOptionalPositional && optionalPositionalGap) {
      continue;
    }
    if (parameter.isNamed) {
      namedArguments.add('${parameter.name}: $dependency');
    } else {
      positionalArguments.add(dependency);
    }
  }

  final variableName = forcedVariableName == null
      ? _uniqueName(_lowerCamel(provider.tokenElement.displayName), usedNames)
      : forcedVariableName;
  return _ResolvedInstantiation(
    typeKey: provider.typeKey,
    typeName: provider.typeName,
    variableName: variableName,
    providerElement: provider.providerElement,
    tokenElement: provider.tokenElement,
    code:
        'final $variableName = ${provider.creationTarget}(${[...positionalArguments, ...namedArguments].join(', ')});',
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

bool _isFutureType(DartType type) {
  return type is InterfaceType &&
      type.element.name == 'Future' &&
      type.typeArguments.length == 1;
}

bool _isVoidType(DartType type) => type is VoidType;

bool _isJsonValueType(DartType type) {
  if (type.isDartCoreNull) {
    return true;
  }
  if (type is InterfaceType) {
    final name = type.element.name;
    return const {'String', 'bool', 'int', 'double', 'num'}.contains(name);
  }
  return false;
}

_OutputCodecKind _outputCodecKind(DartType type) {
  if (_isVoidType(type)) {
    return _OutputCodecKind.voidValue;
  }
  if (_isJsonValueType(type)) {
    return _OutputCodecKind.jsonValue;
  }
  return _OutputCodecKind.dto;
}

DartType? _streamEventType(DartType type) {
  if (type is InterfaceType &&
      type.element.name == 'Stream' &&
      type.typeArguments.length == 1 &&
      type.nullabilitySuffix == NullabilitySuffix.none) {
    return type.typeArguments.single;
  }
  return null;
}

bool _isRawOrNullableStream(DartType type) {
  return type is InterfaceType &&
      type.element.name == 'Stream' &&
      (type.typeArguments.length != 1 ||
          type.typeArguments.single is DynamicType ||
          type.nullabilitySuffix != NullabilitySuffix.none);
}

bool _isFutureOfStream(DartType type) {
  return type is InterfaceType &&
      type.element.name == 'Future' &&
      type.typeArguments.length == 1 &&
      type.typeArguments.single is InterfaceType &&
      (type.typeArguments.single as InterfaceType).element.name == 'Stream';
}

bool _isRpcContext(DartType type) => _rpcContextChecker.isExactlyType(type);

bool _usesLuthorValidation(DartType type) {
  final element = type.element;
  return element is InterfaceElement &&
      _luthorChecker.hasAnnotationOfExact(element);
}

bool _supportsGeneratedOutputCodec(DartType type) {
  final element = type.element;
  if (element is! InterfaceElement) {
    return false;
  }
  final hasFromJsonConstructor =
      element.getNamedConstructor('fromJson') != null;
  final hasStaticFromJson = element.methods.any(
    (method) => method.isStatic && method.displayName == 'fromJson',
  );
  final toJson = element.lookUpMethod(name: 'toJson', library: element.library);
  final hasToJson =
      toJson != null && !toJson.isStatic && toJson.formalParameters.isEmpty;
  return (hasFromJsonConstructor || hasStaticFromJson) && hasToJson;
}

String _typeKeyFor(DartType type) => type.getDisplayString();

String _dependencyTypeKeyFor(DartType type) {
  final display = type.getDisplayString();
  final suffixLength = switch (type.nullabilitySuffix) {
    NullabilitySuffix.none => 0,
    NullabilitySuffix.question || NullabilitySuffix.star => 1,
  };
  return suffixLength == 0 ? display : display.substring(0, display.length - 1);
}

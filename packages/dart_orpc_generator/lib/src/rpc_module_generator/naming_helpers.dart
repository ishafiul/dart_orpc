part of '../rpc_module_generator.dart';

String _rootClientNameFor(
  String moduleName, {
  Set<String> reservedNames = const {},
}) {
  var candidate =
      moduleName.endsWith('Module') && moduleName.length > 'Module'.length
      ? '${moduleName.substring(0, moduleName.length - 'Module'.length)}Client'
      : '${moduleName}Client';
  if (!reservedNames.contains(candidate)) {
    return candidate;
  }
  candidate = '${candidate}Root';
  if (!reservedNames.contains(candidate)) {
    return candidate;
  }
  var suffix = 2;
  var uniqueCandidate = '$candidate$suffix';
  while (reservedNames.contains(uniqueCandidate)) {
    suffix += 1;
    uniqueCandidate = '$candidate$suffix';
  }
  return uniqueCandidate;
}

String _openApiTitleFor(String moduleName) {
  if (moduleName.endsWith('Module') && moduleName.length > 'Module'.length) {
    return '${moduleName.substring(0, moduleName.length - 'Module'.length)} API';
  }
  return '$moduleName API';
}

List<_ResolvedOpenApiSchemaComponent> _collectOpenApiSchemaComponents(
  List<_ControllerBinding> controllerBindings,
) {
  final components = <String, _ResolvedOpenApiSchemaComponent>{};

  late final void Function(Element? element) addComponent;
  late final void Function(DartType type) collectRecursive;

  addComponent = (Element? element) {
    if (element == null) return;
    final name = element.displayName;
    if (components.containsKey(name)) {
      return;
    }
    if (!_luthorChecker.hasAnnotationOfExact(element)) {
      return;
    }

    components[name] = _ResolvedOpenApiSchemaComponent(
      name: name,
      validatorExpression: '\$${name}Schema',
    );

    if (element is InterfaceElement) {
      for (final field in element.fields) {
        if (!field.isStatic && !field.displayName.startsWith('_')) {
          collectRecursive(field.type);
        }
      }
      for (final getter in element.getters) {
        if (!getter.isStatic &&
            !getter.displayName.startsWith('_') &&
            getter.displayName != 'hashCode' &&
            getter.displayName != 'runtimeType') {
          collectRecursive(getter.returnType);
        }
      }
      for (final constructor in element.constructors) {
        for (final parameter in constructor.formalParameters) {
          if (!parameter.displayName.startsWith('_')) {
            collectRecursive(parameter.type);
          }
        }
      }
    }
  };

  collectRecursive = (DartType type) {
    final element = type.element;
    if (element == null) {
      return;
    }

    if (type is InterfaceType) {
      for (final typeArgument in type.typeArguments) {
        collectRecursive(typeArgument);
      }
    }

    addComponent(element);
  };

  for (final controller in controllerBindings) {
    for (final procedure in controller.procedures) {
      if (procedure.path == null) {
        continue;
      }
      if (procedure.outputUsesLuthor) {
        if (procedure.outputTypeElement != null) {
          collectRecursive(
            (procedure.outputTypeElement as InterfaceElement).thisType,
          );
        }
      }
      if (procedure.inputUsesLuthor) {
        if (procedure.inputTypeElement != null) {
          collectRecursive(
            (procedure.inputTypeElement as InterfaceElement).thisType,
          );
        }
      }
      for (final parameter in procedure.restInvocationParameters) {
        if (parameter.source == _InvocationParameterSourceKind.body &&
            parameter.usesLuthor) {
          if (parameter.typeElement != null) {
            collectRecursive(
              (parameter.typeElement as InterfaceElement).thisType,
            );
          }
        }
      }
    }
  }

  return components.values.toList(growable: false)
    ..sort((left, right) => left.name.compareTo(right.name));
}

String _clientClassNameFor(String controllerName) {
  if (controllerName.endsWith('Controller') &&
      controllerName.length > 'Controller'.length) {
    return '${controllerName.substring(0, controllerName.length - 'Controller'.length)}Client';
  }
  return '${controllerName}Client';
}

String _clientGetterNameFor(String namespace) {
  final candidate = namespace
      .split(RegExp(r'[./]'))
      .where((segment) => segment.isNotEmpty)
      .last;
  final sanitized = candidate.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  final prefixed = RegExp(r'^[A-Za-z_]').hasMatch(sanitized)
      ? sanitized
      : 'rpc_$sanitized';
  return _lowerCamel(prefixed);
}

String _uniqueName(String candidate, Set<String> usedNames) {
  var name = candidate;
  var suffix = 2;
  while (!usedNames.add(name)) {
    name = '$candidate$suffix';
    suffix += 1;
  }
  return name;
}

String _lowerCamel(String value) {
  return value.isEmpty ? value : '${value[0].toLowerCase()}${value.substring(1)}';
}

String _camelCase(String value) => _lowerCamel(value);

String _publicProcedureRegistryFactoryNameFor(String moduleName) =>
    'dartOrpcCreate${moduleName}ProcedureRegistry';
String _publicRestRouteRegistryFactoryNameFor(String moduleName) =>
    'dartOrpcCreate${moduleName}RestRouteRegistry';
String _publicProcedureMetadataRegistryFactoryNameFor(String moduleName) =>
    'dartOrpcCreate${moduleName}ProcedureMetadataRegistry';
String _publicOpenApiSchemaRegistryFactoryNameFor(String moduleName) =>
    'dartOrpcCreate${moduleName}OpenApiSchemaRegistry';
String _publicOpenApiDocumentFactoryNameFor(String moduleName) =>
    'dartOrpcCreate${moduleName}OpenApiDocument';
String _publicBuildAppFactoryNameFor(String moduleName) =>
    'dartOrpcBuild${moduleName}RpcApp';

List<_ComposedRpcClientGetter> _resolveComposedRpcClientGetters(
  _ResolvedModule rootModule, {
  required InterfaceElement moduleElement,
}) {
  final getters = <String, _ComposedRpcClientGetter>{};

  for (final importedModule in rootModule.importedModules) {
    final importedClientFieldName =
        '_${_camelCase(importedModule.displayName)}Client';
    for (final controller in importedModule.rpcCompatibleControllers) {
      final getterName = controller.clientGetterName;
      final nextGetter = _ComposedRpcClientGetter(
        clientClassName: controller.clientClassName,
        clientGetterName: getterName,
        initializerExpression: '$importedClientFieldName.$getterName',
      );
      final existingGetter = getters[getterName];
      if (existingGetter == null) {
        getters[getterName] = nextGetter;
        continue;
      }
      if (existingGetter.clientClassName == nextGetter.clientClassName &&
          existingGetter.initializerExpression ==
              nextGetter.initializerExpression) {
        continue;
      }
      throw InvalidGenerationSourceError(
        'Module "${moduleElement.displayName}" resolves RPC client namespace "$getterName" from more than one source.',
        element: moduleElement,
      );
    }
  }

  for (final controller in rootModule.controllerBindings.where(
    (controller) => controller.rpcCompatibleProcedures.isNotEmpty,
  )) {
    getters[controller.clientGetterName] = _ComposedRpcClientGetter(
      clientClassName: controller.clientClassName,
      clientGetterName: controller.clientGetterName,
      initializerExpression: '${controller.clientClassName}(_caller)',
    );
  }

  return getters.values.toList(growable: false);
}

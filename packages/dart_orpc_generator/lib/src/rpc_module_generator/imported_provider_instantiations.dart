part of '../rpc_module_generator.dart';

List<_ResolvedInstantiation> _collectImportedProviderInstantiationsForRoot(
  _ResolvedModule rootModule, {
  required InterfaceElement rootModuleElement,
  required ConstantReader annotation,
}) {
  final ordered = <_ResolvedInstantiation>[];
  final seenModuleKeys = <String>{};

  void visitModule(_ResolvedModule module) {
    if (!seenModuleKeys.add(module.typeKey)) {
      return;
    }
    for (final imported in module.importedModules) {
      visitModule(imported);
    }
    ordered.addAll(module.providerInstantiations);
  }

  for (final imported in rootModule.importedModules) {
    visitModule(imported);
  }

  final byTypeKey = {
    for (final instantiation in ordered) instantiation.typeKey: instantiation,
  };
  final seedKeys = <String>{};

  for (final providerElement in _readInterfaceElements(
    annotation.read('providers'),
    element: rootModuleElement,
    fieldName: 'providers',
  )) {
    for (final parameter
        in _selectUnnamedConstructor(providerElement).formalParameters) {
      final key = _typeKeyFor(parameter.type);
      if (rootModule.importedProviders.containsKey(key)) {
        seedKeys.add(key);
      }
    }
  }

  for (final controllerElement in _readInterfaceElements(
    annotation.read('controllers'),
    element: rootModuleElement,
    fieldName: 'controllers',
  )) {
    for (final parameter
        in _selectUnnamedConstructor(controllerElement).formalParameters) {
      final key = _typeKeyFor(parameter.type);
      if (rootModule.importedProviders.containsKey(key)) {
        seedKeys.add(key);
      }
    }
  }

  if (seedKeys.isEmpty) {
    return const [];
  }

  var requiredKeys = {...seedKeys};
  var progressed = true;
  while (progressed) {
    progressed = false;
    final nextKeys = {...requiredKeys};
    for (final key in requiredKeys) {
      final instantiation = byTypeKey[key];
      if (instantiation == null) {
        continue;
      }
      for (final parameter
          in _selectUnnamedConstructor(instantiation.providerElement)
              .formalParameters) {
        final dependencyKey = _typeKeyFor(parameter.type);
        if (byTypeKey.containsKey(dependencyKey) &&
            nextKeys.add(dependencyKey)) {
          progressed = true;
        }
      }
    }
    requiredKeys = nextKeys;
  }

  return [
    for (final instantiation in ordered)
      if (requiredKeys.contains(instantiation.typeKey)) instantiation,
  ];
}

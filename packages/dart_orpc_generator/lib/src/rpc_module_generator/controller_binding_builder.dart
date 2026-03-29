part of '../rpc_module_generator.dart';

_ControllerBinding _buildControllerBinding(
  InterfaceElement controllerElement, {
  required Map<String, String> availableProviders,
  required Set<String> usedNames,
}) {
  final controllerAnnotation = _controllerChecker.firstAnnotationOfExact(
    controllerElement,
  );
  if (controllerAnnotation == null) {
    throw InvalidGenerationSourceError(
      'Controllers listed in @Module must be annotated with @Controller.',
      element: controllerElement,
    );
  }

  final namespace = ConstantReader(
    controllerAnnotation,
  ).read('namespace').stringValue;
  final controllerGuardBindings = _resolveGuardBindings(
    controllerElement,
    availableProviders: availableProviders,
    ownerLabel: 'controller "${controllerElement.displayName}"',
  );
  final controllerInstantiation = _tryBuildInstantiation(
    controllerElement,
    availableProviders: availableProviders,
    usedNames: usedNames,
  );
  if (controllerInstantiation == null) {
    throw InvalidGenerationSourceError(
      'Unable to resolve controller constructor dependencies for "${controllerElement.displayName}".',
      element: controllerElement,
    );
  }

  final procedures = controllerElement.methods
      .where((method) => _rpcMethodChecker.hasAnnotationOfExact(method))
      .map(
        (method) => _buildMethodBinding(
          namespace,
          method,
          availableProviders: availableProviders,
          inheritedGuardBindings: controllerGuardBindings,
        ),
      )
      .toList(growable: false);
  if (procedures.isEmpty) {
    throw InvalidGenerationSourceError(
      'Controllers must declare at least one @RpcMethod.',
      element: controllerElement,
    );
  }

  return _ControllerBinding(
    typeName: controllerElement.displayName,
    instanceName: controllerInstantiation.variableName,
    instantiationCode: controllerInstantiation.code,
    controllerElement: controllerElement,
    clientClassName: _clientClassNameFor(controllerElement.displayName),
    clientGetterName: _clientGetterNameFor(namespace),
    procedures: procedures,
  );
}

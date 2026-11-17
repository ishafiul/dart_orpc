part of '../../rpc_module_generator.dart';

/// Analyzes a controller the dependency layer has already planned.
///
/// [instanceName] and [instantiationCode] say how the container builds it.
_ControllerBinding _buildControllerBinding(
  InterfaceElement controllerElement, {
  required Map<String, String> availableProviders,
  required String instanceName,
  required String instantiationCode,
}) {
  if (controllerElement is! ClassElement ||
      controllerElement.isAbstract ||
      controllerElement.displayName.startsWith('_')) {
    throw InvalidGenerationSourceError(
      'Controller "${controllerElement.displayName}" must be a public, concrete class because generated code instantiates it from another library.',
      element: controllerElement,
    );
  }
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
  final controllerBearerAuthGuard = _readBearerAuthGuard(
    controllerElement,
    guardBindings: controllerGuardBindings,
  );
  final controllerCustomMetadata = _resolveCustomMetadata(
    controllerElement,
    ownerLabel: 'controller "${controllerElement.displayName}"',
  );
  final procedures = controllerElement.methods
      .where((method) => _rpcMethodChecker.hasAnnotationOfExact(method))
      .map(
        (method) => _buildMethodBinding(
          namespace,
          method,
          availableProviders: availableProviders,
          inheritedGuardBindings: controllerGuardBindings,
          inheritedBearerAuth: controllerBearerAuthGuard,
          inheritedCustomMetadata: controllerCustomMetadata,
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
    instanceName: instanceName,
    instantiationCode: instantiationCode,
    controllerElement: controllerElement,
    clientClassName: _clientClassNameFor(controllerElement.displayName),
    clientGetterName: _clientGetterNameFor(namespace),
    procedures: procedures,
  );
}

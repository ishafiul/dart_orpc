part of '../../rpc_module_generator.dart';

void _validateUniqueProcedureContracts(
  _ResolvedModule rootModule, {
  required InterfaceElement moduleElement,
}) {
  final rpcOwners = <String, String>{};
  final restOwners = <String, String>{};

  for (final controller in rootModule.allControllers) {
    for (final procedure in controller.procedures) {
      final owner = '${controller.typeName}.${procedure.methodName}';
      if (procedure.supportsRpcGeneration) {
        _recordUniqueContract(
          rpcOwners,
          signature: procedure.rpcMethod,
          owner: owner,
          description: 'RPC method',
          moduleElement: moduleElement,
        );
      }

      final path = procedure.path;
      if (path != null) {
        _recordUniqueContract(
          restOwners,
          signature: _normalizedRestRouteSignature(path),
          owner: owner,
          description: 'REST route',
          moduleElement: moduleElement,
        );
      }
    }
  }
}

void _recordUniqueContract(
  Map<String, String> owners, {
  required String signature,
  required String owner,
  required String description,
  required InterfaceElement moduleElement,
}) {
  final existingOwner = owners[signature];
  if (existingOwner == null) {
    owners[signature] = owner;
    return;
  }

  throw InvalidGenerationSourceError(
    'Module "${moduleElement.displayName}" declares duplicate $description '
    '"$signature" in $existingOwner and $owner.',
    element: moduleElement,
  );
}

String _normalizedRestRouteSignature(_ResolvedPathMapping path) {
  var normalizedPath = _normalizeRestPath(path.path);
  if (normalizedPath.length > 1 && normalizedPath.endsWith('/')) {
    normalizedPath = normalizedPath.substring(0, normalizedPath.length - 1);
  }

  final normalizedSegments = normalizedPath
      .split('/')
      .map((segment) => segment.startsWith(':') ? ':' : segment);
  return '${path.method.toUpperCase()} ${normalizedSegments.join('/')}';
}

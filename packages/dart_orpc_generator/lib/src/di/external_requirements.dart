import 'declarations.dart';
import 'errors.dart';
import 'resolution.dart';

/// Finds what a module needs that nothing in the graph provides, so the app
/// must pass it in.
final class ExternalRequirements {
  const ExternalRequirements();

  /// Required parameters of [module]'s providers and controllers that are
  /// neither in [visibleKeys] nor provided by the module itself, in the order
  /// first needed. Parameters whose type cannot be passed in are left for
  /// construction planning to report.
  ///
  /// Throws [PrivateGlobalProviderError] when one names a provider a global
  /// module keeps private, and [PrivateDependencyError] when generated code
  /// cannot name its type.
  List<ExternalRequirement> collect(
    ModuleDeclaration module, {
    required Set<String> visibleKeys,
    required Set<String> privateGlobalKeys,
  }) {
    final localKeys = {
      for (final provider in module.providers) provider.token.key,
    };
    final requirements = <String, ExternalRequirement>{};

    void require(DependencyParameter parameter) {
      final type = parameter.externalType;
      if (parameter.kind.isOptional || type == null) return;
      final key = parameter.dependencyKey;
      if (visibleKeys.contains(key) || localKeys.contains(key)) return;
      if (privateGlobalKeys.contains(key)) {
        throw PrivateGlobalProviderError(module);
      }
      if (type.isPrivate) {
        throw PrivateDependencyError(module: module, typeName: type.name);
      }
      requirements.putIfAbsent(
        key,
        () => ExternalRequirement(
          instance: InstanceRef(
            kind: InstanceKind.external,
            moduleKey: module.key,
            token: DependencyToken(
              key: key,
              typeName: type.name,
              name: type.name,
            ),
          ),
          type: type,
        ),
      );
    }

    for (final provider in module.providers) {
      provider.parameters.forEach(require);
    }
    for (final controller in module.controllers) {
      controller.parameters.forEach(require);
    }
    return requirements.values.toList(growable: false);
  }
}

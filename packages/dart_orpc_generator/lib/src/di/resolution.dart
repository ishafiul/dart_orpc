/// What the dependency resolver produces: which objects the generated
/// container holds, in what order they are built, and what each receives.
library;

import 'declarations.dart';

/// What kind of object an [InstanceRef] names.
enum InstanceKind {
  /// Built by its module from a [ProviderDeclaration].
  provider,

  /// Not provided by the graph; the app passes it in.
  external,

  /// Built by its module from a [ControllerDeclaration].
  controller,
}

/// Names one object in the generated container.
///
/// Equal refs are the same object. A provider is identified by the module
/// that declares it, so every module that sees it through imports, exports or
/// a global module shares one instance.
final class InstanceRef {
  const InstanceRef({
    required this.kind,
    required this.moduleKey,
    required this.token,
  });

  final InstanceKind kind;

  /// The module that builds it, or for an external, the module that needs it.
  final String moduleKey;

  final DependencyToken token;

  @override
  bool operator ==(Object other) =>
      other is InstanceRef &&
      other.kind == kind &&
      other.moduleKey == moduleKey &&
      other.token.key == token.key;

  @override
  int get hashCode => Object.hash(kind, moduleKey, token.key);

  @override
  String toString() => 'InstanceRef(${kind.name}, $moduleKey, ${token.key})';
}

/// The object passed for one parameter.
final class ResolvedArgument {
  const ResolvedArgument({required this.parameter, required this.instance});

  final DependencyParameter parameter;
  final InstanceRef instance;
}

/// How to build one provider. Optional parameters with nothing to pass are
/// left out of [arguments].
final class ProviderConstruction {
  const ProviderConstruction({
    required this.instance,
    required this.declaration,
    required this.arguments,
  });

  final InstanceRef instance;
  final ProviderDeclaration declaration;
  final List<ResolvedArgument> arguments;
}

/// How to build one controller.
final class ControllerConstruction {
  const ControllerConstruction({
    required this.instance,
    required this.declaration,
    required this.arguments,
  });

  final InstanceRef instance;
  final ControllerDeclaration declaration;
  final List<ResolvedArgument> arguments;
}

/// A dependency the app must pass in because no module in the graph provides
/// it.
final class ExternalRequirement {
  const ExternalRequirement({required this.instance, required this.type});

  final InstanceRef instance;
  final ExternalType type;
}

/// One module after resolution.
final class ResolvedModuleScope {
  const ResolvedModuleScope({
    required this.declaration,
    required this.imports,
    required this.externalRequirements,
    required this.providers,
    required this.controllers,
    required this.injectable,
  });

  final ModuleDeclaration declaration;

  /// The modules in `@Module(imports: [...])`, in order.
  final List<ResolvedModuleScope> imports;

  /// What the app must pass in for this module, in the order first needed.
  final List<ExternalRequirement> externalRequirements;

  /// This module's providers, each after everything it depends on.
  final List<ProviderConstruction> providers;

  /// This module's controllers, in declaration order.
  final List<ControllerConstruction> controllers;

  /// Everything this module's code may inject, by token key: imported and
  /// global providers, external requirements and its own providers.
  final Map<String, InstanceRef> injectable;

  String get key => declaration.key;
}

/// The whole resolved module graph.
final class ResolvedDependencyGraph {
  const ResolvedDependencyGraph({
    required this.modules,
    required this.globalExports,
  });

  /// Every module once, each after the modules it imports. The root is last.
  final List<ResolvedModuleScope> modules;

  /// Providers exported by global modules, in the order they were found.
  final List<InstanceRef> globalExports;

  ResolvedModuleScope get root => modules.last;
}

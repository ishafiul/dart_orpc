import '../graph/depth_first_search.dart';
import '../graph/topological_sort.dart';
import 'declarations.dart';
import 'errors.dart';
import 'provider_bindings.dart';
import 'resolution.dart';

/// Decides the order a module builds its providers in, and what each provider
/// and controller receives.
final class ConstructionPlanner {
  const ConstructionPlanner();

  /// Plans [module]'s providers, each after its required dependencies.
  ///
  /// [imported] is what the module sees from imports and global modules;
  /// [externals] is what the app passes in.
  ///
  /// Throws [DuplicateProviderError], [ImportedProviderConflictError],
  /// [ProviderCycleError] or [UnresolvedProvidersError].
  List<ProviderConstruction> planProviders(
    ModuleDeclaration module, {
    required Map<String, ProviderBinding> imported,
    required List<ExternalRequirement> externals,
  }) {
    final providers = module.providers;
    final declaredKeys = <String>{};
    for (final provider in providers) {
      if (!declaredKeys.add(provider.token.key)) {
        throw DuplicateProviderError(module: module, provider: provider);
      }
      final conflict = imported[provider.token.key];
      if (conflict != null) {
        throw ImportedProviderConflictError(
          module: module,
          provider: provider,
          importedSource: conflict.sourceLabel,
        );
      }
    }

    final available = <String, InstanceRef>{
      for (final binding in imported.values)
        binding.token.key: binding.instance,
      for (final external in externals)
        external.instance.token.key: external.instance,
    };
    final dependencies = {
      for (final provider in providers)
        provider.token.key: [
          for (final parameter in provider.parameters)
            if (!parameter.kind.isOptional) parameter.dependencyKey,
        ],
    };
    final sorted = topologicalSort<ProviderDeclaration, String>(
      providers,
      keyOf: (provider) => provider.token.key,
      dependenciesOf: (provider) => dependencies[provider.token.key]!,
      available: available.keys,
    );
    if (sorted.unresolved.isNotEmpty) {
      throw _unresolvedProvidersError(module, sorted.unresolved, dependencies);
    }

    final constructions = <ProviderConstruction>[];
    for (final provider in sorted.ordered) {
      final arguments = planArguments(provider.parameters, available);
      if (arguments == null) {
        throw StateError(
          'Invalid dependency order for "${provider.token.typeName}".',
        );
      }
      final instance = InstanceRef(
        kind: InstanceKind.provider,
        moduleKey: module.key,
        token: provider.token,
      );
      constructions.add(
        ProviderConstruction(
          instance: instance,
          declaration: provider,
          arguments: arguments,
        ),
      );
      available[provider.token.key] = instance;
    }
    return constructions;
  }

  /// Plans [module]'s controllers against everything it can inject.
  ///
  /// Throws [UnresolvedControllerError] when a controller needs something
  /// [injectable] does not hold.
  List<ControllerConstruction> planControllers(
    ModuleDeclaration module, {
    required Map<String, InstanceRef> injectable,
  }) {
    return [
      for (final controller in module.controllers)
        ControllerConstruction(
          instance: InstanceRef(
            kind: InstanceKind.controller,
            moduleKey: module.key,
            token: controller.token,
          ),
          declaration: controller,
          arguments:
              planArguments(controller.parameters, injectable) ??
              (throw UnresolvedControllerError(controller)),
        ),
    ];
  }

  /// What to pass for each of [parameters] from [available], or `null` when a
  /// required one is missing.
  ///
  /// A missing optional parameter is left out. After a missing optional
  /// positional parameter, later optional positional ones are left out too,
  /// because positional arguments cannot skip a slot.
  List<ResolvedArgument>? planArguments(
    List<DependencyParameter> parameters,
    Map<String, InstanceRef> available,
  ) {
    final arguments = <ResolvedArgument>[];
    var skippedOptionalPositional = false;
    for (final parameter in parameters) {
      final instance = available[parameter.dependencyKey];
      if (instance == null) {
        if (!parameter.kind.isOptional) return null;
        if (parameter.kind == ParameterKind.optionalPositional) {
          skippedOptionalPositional = true;
        }
        continue;
      }
      if (parameter.kind == ParameterKind.optionalPositional &&
          skippedOptionalPositional) {
        continue;
      }
      arguments.add(ResolvedArgument(parameter: parameter, instance: instance));
    }
    return arguments;
  }
}

DependencyResolutionError _unresolvedProvidersError(
  ModuleDeclaration module,
  List<ProviderDeclaration> unresolved,
  Map<String, List<String>> dependencies,
) {
  final unresolvedByKey = {
    for (final provider in unresolved) provider.token.key: provider,
  };
  final cycle = findDependencyCycle<ProviderDeclaration, String>(
    unresolved,
    keyOf: (provider) => provider.token.key,
    dependenciesOf: (provider) => [
      for (final key in dependencies[provider.token.key]!)
        if (unresolvedByKey[key] case final dependency?) dependency,
    ],
  );
  if (cycle != null) return ProviderCycleError(module: module, cycle: cycle);
  return UnresolvedProvidersError(module: module, providers: unresolved);
}

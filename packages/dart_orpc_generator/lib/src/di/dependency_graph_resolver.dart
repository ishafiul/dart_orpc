import 'construction_planner.dart';
import 'declarations.dart';
import 'errors.dart';
import 'export_resolution.dart';
import 'external_requirements.dart';
import 'global_providers.dart';
import 'module_ordering.dart';
import 'provider_bindings.dart';
import 'resolution.dart';

/// Resolves a module graph: which objects the app builds, in what order, and
/// what each one receives.
abstract interface class DependencyGraphResolver {
  /// Resolves the graph reachable from [rootKey], reading modules from
  /// [catalog].
  ///
  /// Throws a [DependencyResolutionError] when the graph is invalid.
  ResolvedDependencyGraph resolve(String rootKey, ModuleCatalog catalog);
}

/// The module rules dart_orpc uses:
///
/// - Each module is resolved once, however many imports reach it, so every
///   provider has one instance.
/// - A module sees its own providers, what its imports export, and what
///   global modules export.
/// - A required dependency nothing provides becomes an [ExternalRequirement]
///   the app passes in.
final class ModuleDependencyResolver implements DependencyGraphResolver {
  const ModuleDependencyResolver({
    this.ordering = const ModuleOrdering(),
    this.externalRequirements = const ExternalRequirements(),
    this.planner = const ConstructionPlanner(),
    this.exports = const ExportResolution(),
  });

  final ModuleOrdering ordering;
  final ExternalRequirements externalRequirements;
  final ConstructionPlanner planner;
  final ExportResolution exports;

  @override
  ResolvedDependencyGraph resolve(String rootKey, ModuleCatalog catalog) {
    final modules = ordering.order(rootKey, catalog);
    final globals = GlobalProviders.index(modules);

    final scopes = <String, ResolvedModuleScope>{};
    final exportsByModule = <String, Map<String, ProviderBinding>>{};
    for (final module in modules) {
      final (scope, moduleExports) = _resolveModule(
        module,
        globals: globals,
        scopes: scopes,
        exportsByModule: exportsByModule,
      );
      scopes[module.key] = scope;
      exportsByModule[module.key] = moduleExports;
    }

    // Global modules' resolved exports must agree with each other too.
    var globalExports = <String, ProviderBinding>{};
    for (final module in modules.where((module) => module.isGlobal)) {
      final bindings = ProviderBindings(module, globalExports);
      exportsByModule[module.key]!.values.forEach(bindings.add);
      globalExports = bindings.asMap;
    }

    return ResolvedDependencyGraph(
      modules: [for (final module in modules) scopes[module.key]!],
      globalExports: [
        for (final binding in globals.bindings.values) binding.instance,
      ],
    );
  }

  (ResolvedModuleScope, Map<String, ProviderBinding>) _resolveModule(
    ModuleDeclaration module, {
    required GlobalProviders globals,
    required Map<String, ResolvedModuleScope> scopes,
    required Map<String, Map<String, ProviderBinding>> exportsByModule,
  }) {
    final imported = ProviderBindings(module, globals.bindings);
    for (final importKey in module.header.importKeys) {
      exportsByModule[importKey]!.values.forEach(imported.add);
    }
    final localKeys = {
      for (final provider in module.providers) provider.token.key,
    };
    // A global module's own providers win over the global view of them.
    final visible = {
      for (final MapEntry(:key, :value) in imported.asMap.entries)
        if (!(module.isGlobal && localKeys.contains(key))) key: value,
    };
    for (final provider in module.providers) {
      if (globals.shadows(module, provider)) {
        throw GlobalProviderShadowedError(module: module, provider: provider);
      }
    }

    final externals = externalRequirements.collect(
      module,
      visibleKeys: visible.keys.toSet(),
      privateGlobalKeys: globals.privateKeys,
    );
    final providers = planner.planProviders(
      module,
      imported: visible,
      externals: externals,
    );
    final injectable = <String, InstanceRef>{
      for (final binding in visible.values) binding.token.key: binding.instance,
      for (final external in externals)
        external.instance.token.key: external.instance,
      for (final provider in providers)
        provider.instance.token.key: provider.instance,
    };
    final controllers = planner.planControllers(module, injectable: injectable);

    final moduleExports = exports.resolve(
      module,
      importedExports: {
        for (final importKey in module.header.importKeys)
          importKey: exportsByModule[importKey]!,
      },
      imported: visible,
      local: {
        for (final provider in module.providers)
          provider.token.key: ProviderBinding.local(module, provider),
      },
    );

    return (
      ResolvedModuleScope(
        declaration: module,
        imports: [
          for (final importKey in module.header.importKeys) scopes[importKey]!,
        ],
        externalRequirements: externals,
        providers: providers,
        controllers: controllers,
        injectable: Map.unmodifiable(injectable),
      ),
      moduleExports,
    );
  }
}

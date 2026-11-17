import 'declarations.dart';
import 'errors.dart';
import 'provider_bindings.dart';
import 'resolution.dart';

/// A provider a module exports, directly or through an exported import, and
/// the module that declares it.
final class _DeclaredExport {
  const _DeclaredExport({required this.provider, required this.owner});

  final ProviderDeclaration provider;
  final ModuleDeclaration owner;

  DependencyToken get token => provider.token;
}

/// What global modules make visible everywhere, worked out from declarations
/// before any module is resolved.
final class GlobalProviders {
  const GlobalProviders._({
    required this.bindings,
    required this.ownerKeys,
    required this.privateKeys,
  });

  /// Indexes the global modules among [modules], which must be in build
  /// order.
  ///
  /// Throws [GlobalExportConflictError] when two global modules export the
  /// same type, and [AmbiguousExportError] when one module exports two
  /// providers of a type.
  factory GlobalProviders.index(List<ModuleDeclaration> modules) {
    final moduleByKey = {for (final module in modules) module.key: module};
    final cache = <String, Map<String, _DeclaredExport>>{};
    final globalModules = modules.where((module) => module.isGlobal).toList();

    final exported = <String, _DeclaredExport>{};
    for (final module in globalModules) {
      for (final export in _declaredExports(
        module,
        moduleByKey,
        cache,
      ).values) {
        final existing = exported[export.token.key];
        if (existing != null && existing.owner.key != export.owner.key) {
          throw GlobalExportConflictError(
            module: module,
            typeName: export.token.typeName,
            firstOwnerName: existing.owner.name,
            secondOwnerName: export.owner.name,
          );
        }
        exported[export.token.key] = export;
      }
    }

    final privateKeys = <String>{};
    for (final module in globalModules) {
      final exportedKeys = _declaredExports(module, moduleByKey, cache).keys;
      for (final provider in module.providers) {
        if (!exportedKeys.contains(provider.token.key)) {
          privateKeys.add(provider.token.key);
        }
      }
    }

    return GlobalProviders._(
      bindings: {
        for (final export in exported.values)
          export.token.key: ProviderBinding(
            instance: InstanceRef(
              kind: InstanceKind.provider,
              moduleKey: export.owner.key,
              token: export.token,
            ),
            sourceLabel:
                'global provider "${export.token.typeName}" from '
                '"${export.owner.name}"',
          ),
      },
      ownerKeys: {
        for (final export in exported.values)
          export.token.key: export.owner.key,
      },
      privateKeys: privateKeys,
    );
  }

  /// Exported global providers, by token key, in the order found.
  final Map<String, ProviderBinding> bindings;

  /// The module that declares each exported global provider, by token key.
  final Map<String, String> ownerKeys;

  /// Token keys of providers global modules declare but do not export.
  final Set<String> privateKeys;

  /// Whether [module] declares a provider a global module exports from
  /// elsewhere.
  bool shadows(ModuleDeclaration module, ProviderDeclaration provider) {
    final owner = ownerKeys[provider.token.key];
    return owner != null && owner != module.key;
  }
}

/// The providers [module] exports, including those it re-exports from
/// imports. Unknown exports are skipped here; resolving the module reports
/// them.
Map<String, _DeclaredExport> _declaredExports(
  ModuleDeclaration module,
  Map<String, ModuleDeclaration> moduleByKey,
  Map<String, Map<String, _DeclaredExport>> cache,
) {
  final cached = cache[module.key];
  if (cached != null) return cached;

  final imports = [
    for (final key in module.header.importKeys) moduleByKey[key]!,
  ];
  final imported = <String, _DeclaredExport>{};
  for (final importedModule in imports) {
    for (final export in _declaredExports(
      importedModule,
      moduleByKey,
      cache,
    ).values) {
      _record(imported, export, module);
    }
  }
  final local = {
    for (final provider in module.providers)
      provider.token.key: _DeclaredExport(provider: provider, owner: module),
  };

  final exported = <String, _DeclaredExport>{};
  for (final export in module.exports) {
    final importedModule = imports.where((import) => import.key == export.key);
    if (importedModule.isNotEmpty) {
      for (final reexport in _declaredExports(
        importedModule.single,
        moduleByKey,
        cache,
      ).values) {
        _record(exported, reexport, module);
      }
      continue;
    }
    final provider = local[export.key] ?? imported[export.key];
    if (provider != null) _record(exported, provider, module);
  }
  return cache[module.key] = exported;
}

void _record(
  Map<String, _DeclaredExport> target,
  _DeclaredExport export,
  ModuleDeclaration module,
) {
  final existing = target[export.token.key];
  if (existing != null && existing.owner.key != export.owner.key) {
    throw AmbiguousExportError(module: module, typeName: export.token.typeName);
  }
  target[export.token.key] = export;
}

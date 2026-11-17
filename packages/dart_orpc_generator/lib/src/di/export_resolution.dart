import 'declarations.dart';
import 'errors.dart';
import 'provider_bindings.dart';

/// Works out what a module makes available to the modules that import it.
final class ExportResolution {
  const ExportResolution();

  /// [module]'s exports, by token key. An exported module contributes
  /// everything that module exports.
  ///
  /// [importedExports] holds the exports of each imported module, by module
  /// key. Throws [UnknownExportError] for an export that is neither the
  /// module's own provider nor available from its imports, and
  /// [AmbiguousProviderError] when two exports bind one type differently.
  Map<String, ProviderBinding> resolve(
    ModuleDeclaration module, {
    required Map<String, Map<String, ProviderBinding>> importedExports,
    required Map<String, ProviderBinding> imported,
    required Map<String, ProviderBinding> local,
  }) {
    final exported = ProviderBindings(module);
    for (final export in module.exports) {
      final moduleExports = importedExports[export.key];
      if (moduleExports != null) {
        moduleExports.values.forEach(exported.add);
        continue;
      }
      final provider = local[export.key] ?? imported[export.key];
      if (provider == null) {
        throw UnknownExportError(module: module, export: export);
      }
      exported.add(provider);
    }
    return exported.asMap;
  }
}

import '../graph/depth_first_search.dart';
import 'declarations.dart';
import 'errors.dart';

/// Puts a module graph in build order: every module after the modules it
/// imports, each once, the root last.
final class ModuleOrdering {
  const ModuleOrdering();

  /// Reads each module's header while walking imports from [rootKey], then
  /// each module's full declaration in build order.
  ///
  /// Throws [ImportCycleError] when imports form a loop.
  List<ModuleDeclaration> order(String rootKey, ModuleCatalog catalog) {
    final headers = <String, ModuleHeader>{};
    ModuleHeader headerOf(String key) =>
        headers.putIfAbsent(key, () => catalog.header(key));

    final List<ModuleHeader> ordered;
    try {
      ordered = depthFirstPostorder<ModuleHeader, String>(
        [headerOf(rootKey)],
        keyOf: (module) => module.key,
        dependenciesOf: (module) => module.importKeys.map(headerOf),
      );
    } on DependencyCycle<ModuleHeader> catch (cycle) {
      throw ImportCycleError(cycle.path);
    }
    return [for (final module in ordered) catalog.declaration(module.key)];
  }
}

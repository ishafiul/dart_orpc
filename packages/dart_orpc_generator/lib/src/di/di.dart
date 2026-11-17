/// Dependency injection for dart_orpc modules, resolved at build time.
///
/// This layer knows modules, providers, controllers, imports, exports and
/// global modules, and nothing about the analyzer or generated code. The
/// generator reads `@Module` annotations into [ModuleDeclaration]s, resolves
/// them with a [DependencyGraphResolver], and writes the container from the
/// [ResolvedDependencyGraph].
library;

export 'construction_planner.dart' show ConstructionPlanner;
export 'declarations.dart';
export 'dependency_graph_resolver.dart';
export 'errors.dart';
export 'export_resolution.dart' show ExportResolution;
export 'external_requirements.dart' show ExternalRequirements;
export 'module_ordering.dart' show ModuleOrdering;
export 'resolution.dart';

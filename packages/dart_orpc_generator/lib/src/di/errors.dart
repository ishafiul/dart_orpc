/// Why a module graph cannot be resolved.
///
/// Each error carries the [DependencyResolutionError.origin] of the
/// declaration at fault, so the caller can point at the source.
library;

import 'declarations.dart';

sealed class DependencyResolutionError implements Exception {
  const DependencyResolutionError();

  String get message;

  /// The [origin] of the module, provider or controller at fault.
  Object? get origin;

  @override
  String toString() => '$runtimeType: $message';
}

/// Modules import each other in a loop.
final class ImportCycleError extends DependencyResolutionError {
  const ImportCycleError(this.path);

  /// The loop, with the repeated module at both ends.
  final List<ModuleHeader> path;

  @override
  String get message =>
      'Detected circular @Module.imports chain: '
      '${path.map((module) => module.name).join(' -> ')}.';

  @override
  Object? get origin => path.last.origin;
}

/// Two global modules export the same provider type.
final class GlobalExportConflictError extends DependencyResolutionError {
  const GlobalExportConflictError({
    required this.module,
    required this.typeName,
    required this.firstOwnerName,
    required this.secondOwnerName,
  });

  final ModuleDeclaration module;
  final String typeName;
  final String firstOwnerName;
  final String secondOwnerName;

  @override
  String get message =>
      'Global provider "$typeName" is exported by both "$firstOwnerName" and '
      '"$secondOwnerName".';

  @override
  Object? get origin => module.origin;
}

/// A module's exports name two different providers of the same type.
final class AmbiguousExportError extends DependencyResolutionError {
  const AmbiguousExportError({required this.module, required this.typeName});

  final ModuleDeclaration module;
  final String typeName;

  @override
  String get message =>
      'Module "${module.name}" exports provider "$typeName" from more than one '
      'source.';

  @override
  Object? get origin => module.origin;
}

/// A module declares a provider that a global module already exports.
final class GlobalProviderShadowedError extends DependencyResolutionError {
  const GlobalProviderShadowedError({
    required this.module,
    required this.provider,
  });

  final ModuleDeclaration module;
  final ProviderDeclaration provider;

  @override
  String get message =>
      'Module "${module.name}" declares provider '
      '"${provider.token.typeName}" that shadows a global provider.';

  @override
  Object? get origin => provider.origin;
}

/// A module needs a provider that a global module declares but does not
/// export.
final class PrivateGlobalProviderError extends DependencyResolutionError {
  const PrivateGlobalProviderError(this.module);

  final ModuleDeclaration module;

  @override
  String get message =>
      'Module "${module.name}" requires a private provider that is declared '
      'by a global module. Export the provider from that module.';

  @override
  Object? get origin => module.origin;
}

/// A module needs a dependency from outside whose type generated code cannot
/// name.
final class PrivateDependencyError extends DependencyResolutionError {
  const PrivateDependencyError({required this.module, required this.typeName});

  final ModuleDeclaration module;
  final String typeName;

  @override
  String get message =>
      'Module "${module.name}" requires private dependency "$typeName", which '
      'generated code cannot reference from another library.';

  @override
  Object? get origin => module.origin;
}

/// A module lists the same provider type twice.
final class DuplicateProviderError extends DependencyResolutionError {
  const DuplicateProviderError({required this.module, required this.provider});

  final ModuleDeclaration module;
  final ProviderDeclaration provider;

  @override
  String get message =>
      'Module "${module.name}" declares provider '
      '"${provider.token.typeName}" more than once.';

  @override
  Object? get origin => provider.origin;
}

/// A module declares a provider type it also receives from an import.
final class ImportedProviderConflictError extends DependencyResolutionError {
  const ImportedProviderConflictError({
    required this.module,
    required this.provider,
    required this.importedSource,
  });

  final ModuleDeclaration module;
  final ProviderDeclaration provider;

  /// Where the imported provider comes from, for example
  /// `provider "UserService" from module "UserModule"`.
  final String importedSource;

  @override
  String get message =>
      'Module "${module.name}" declares provider '
      '"${provider.token.typeName}" that conflicts with $importedSource.';

  @override
  Object? get origin => provider.origin;
}

/// A module's providers depend on each other in a loop.
final class ProviderCycleError extends DependencyResolutionError {
  const ProviderCycleError({required this.module, required this.cycle});

  final ModuleDeclaration module;

  /// The loop, with the repeated provider at both ends.
  final List<ProviderDeclaration> cycle;

  @override
  String get message =>
      'Provider dependency cycle: '
      '${cycle.map((provider) => provider.token.typeName).join(' -> ')}.';

  @override
  Object? get origin => module.origin;
}

/// Some of a module's providers need something nothing provides, and that
/// the app cannot pass in.
final class UnresolvedProvidersError extends DependencyResolutionError {
  const UnresolvedProvidersError({
    required this.module,
    required this.providers,
  });

  final ModuleDeclaration module;
  final List<ProviderDeclaration> providers;

  @override
  String get message =>
      'Unable to resolve provider dependencies for: '
      '${providers.map((provider) => provider.token.typeName).join(', ')}.';

  @override
  Object? get origin => module.origin;
}

/// A module exports something that is neither its own provider nor
/// available from its imports.
final class UnknownExportError extends DependencyResolutionError {
  const UnknownExportError({required this.module, required this.export});

  final ModuleDeclaration module;
  final ModuleExport export;

  @override
  String get message => export.isModule
      ? 'Module "${module.name}" may only export modules listed in '
            '@Module.imports. Unknown module export "${export.name}".'
      : 'Module "${module.name}" may only export its own providers or '
            'providers/modules from @Module.imports. Unknown export '
            '"${export.name}".';

  @override
  Object? get origin => module.origin;
}

/// A module receives two different providers of the same type.
final class AmbiguousProviderError extends DependencyResolutionError {
  const AmbiguousProviderError({
    required this.module,
    required this.typeName,
    required this.firstSource,
    required this.secondSource,
  });

  final ModuleDeclaration module;
  final String typeName;
  final String firstSource;
  final String secondSource;

  @override
  String get message =>
      'Module "${module.name}" resolves provider type "$typeName" from more '
      'than one source ($firstSource, $secondSource).';

  @override
  Object? get origin => module.origin;
}

/// A controller needs something its module cannot inject.
final class UnresolvedControllerError extends DependencyResolutionError {
  const UnresolvedControllerError(this.controller);

  final ControllerDeclaration controller;

  @override
  String get message =>
      'Unable to resolve controller constructor dependencies for '
      '"${controller.token.name}".';

  @override
  Object? get origin => controller.origin;
}

/// What the dependency resolver reads: modules, providers and controllers as
/// plain data.
///
/// Nothing here refers to the analyzer. The generator builds these from
/// `@Module` annotations; tests build them directly. Each declaration may carry
/// an [origin], an opaque handle the resolver never inspects and hands back in
/// its errors, so the caller can point at the source that caused them.
library;

/// A type that can be injected.
final class DependencyToken {
  const DependencyToken({
    required this.key,
    required this.typeName,
    required this.name,
  });

  /// Identifies the type. Two tokens with the same key are the same
  /// injectable type, for example `Repository<User>`.
  final String key;

  /// The type as shown in messages, for example `Repository<User>`.
  final String typeName;

  /// The type's simple name, for example `Repository`.
  final String name;

  @override
  bool operator ==(Object other) =>
      other is DependencyToken && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'DependencyToken($key)';
}

/// How a constructor or factory parameter is passed.
enum ParameterKind {
  requiredPositional,
  optionalPositional,
  requiredNamed,
  optionalNamed;

  bool get isOptional => this == optionalPositional || this == optionalNamed;

  bool get isNamed => this == requiredNamed || this == optionalNamed;
}

/// A type an app can supply from outside the module graph.
final class ExternalType {
  const ExternalType({required this.name, this.origin});

  /// The type's simple name.
  final String name;

  final Object? origin;

  /// Whether generated code in another library cannot refer to the type.
  bool get isPrivate => name.startsWith('_');
}

/// One parameter of a provider's constructor or factory, or of a controller's
/// constructor.
final class DependencyParameter {
  const DependencyParameter({
    required this.name,
    required this.kind,
    required this.dependencyKey,
    this.externalType,
  });

  final String name;
  final ParameterKind kind;

  /// The [DependencyToken.key] this parameter asks for, without nullability.
  final String dependencyKey;

  /// The type an app supplies when no module provides [dependencyKey], or
  /// `null` when it cannot be supplied that way (for example a function type
  /// or `Object`).
  final ExternalType? externalType;
}

/// Something a module constructs: a class, an interface bound to a class, or
/// an interface bound to a factory.
final class ProviderDeclaration {
  const ProviderDeclaration({
    required this.token,
    required this.parameters,
    this.origin,
  });

  /// The type consumers inject.
  final DependencyToken token;

  /// What constructing it needs.
  final List<DependencyParameter> parameters;

  final Object? origin;
}

/// A controller a module constructs. Controllers consume providers but are not
/// injectable themselves.
final class ControllerDeclaration {
  const ControllerDeclaration({
    required this.token,
    required this.parameters,
    this.origin,
  });

  final DependencyToken token;
  final List<DependencyParameter> parameters;
  final Object? origin;
}

/// An entry of `@Module(exports: [...])`.
final class ModuleExport {
  const ModuleExport({
    required this.key,
    required this.name,
    required this.isModule,
  });

  /// The exported provider's token key, or the exported module's key.
  final String key;

  final String name;

  /// Whether the entry names a module rather than a provider.
  final bool isModule;
}

/// What the resolver needs to order modules: identity and imports.
final class ModuleHeader {
  const ModuleHeader({
    required this.key,
    required this.name,
    required this.importKeys,
    this.origin,
  });

  final String key;
  final String name;

  /// [key]s of the modules in `@Module(imports: [...])`, in order.
  final List<String> importKeys;

  final Object? origin;
}

/// A whole `@Module`.
final class ModuleDeclaration {
  const ModuleDeclaration({
    required this.header,
    this.providers = const [],
    this.controllers = const [],
    this.exports = const [],
    this.isGlobal = false,
  });

  final ModuleHeader header;
  final List<ProviderDeclaration> providers;
  final List<ControllerDeclaration> controllers;
  final List<ModuleExport> exports;

  /// Whether the module's exported providers are visible to every module in
  /// the graph without an import.
  final bool isGlobal;

  String get key => header.key;
  String get name => header.name;
  Object? get origin => header.origin;
}

/// Where the resolver reads modules from.
///
/// The resolver asks for each module's [header] while it orders the graph,
/// then for each [declaration] once, dependencies first. A source that reads
/// lazily therefore reports problems in a module's providers only after the
/// import graph is known to be valid.
abstract interface class ModuleCatalog {
  ModuleHeader header(String moduleKey);

  ModuleDeclaration declaration(String moduleKey);
}

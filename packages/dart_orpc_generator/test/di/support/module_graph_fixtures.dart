import 'package:dart_orpc_generator/src/di/di.dart';

/// A token whose key, type name and simple name are all [name].
DependencyToken token(String name) =>
    DependencyToken(key: name, typeName: name, name: name);

/// A constructor parameter asking for [type].
///
/// By default the app could pass [type] in if nothing provides it; set
/// [injectableFromOutside] to `false` for types it cannot, such as functions.
DependencyParameter needs(
  String type, {
  ParameterKind kind = ParameterKind.requiredPositional,
  String? name,
  bool injectableFromOutside = true,
}) => DependencyParameter(
  name: name ?? _lowerFirst(type),
  kind: kind,
  dependencyKey: type,
  externalType: injectableFromOutside
      ? ExternalType(name: type, origin: 'type $type')
      : null,
);

ProviderDeclaration provider(
  String type, [
  List<DependencyParameter> parameters = const [],
]) => ProviderDeclaration(
  token: token(type),
  parameters: parameters,
  origin: 'provider $type',
);

ControllerDeclaration controller(
  String type, [
  List<DependencyParameter> parameters = const [],
]) => ControllerDeclaration(
  token: token(type),
  parameters: parameters,
  origin: 'controller $type',
);

ModuleExport exportsProvider(String type) =>
    ModuleExport(key: type, name: type, isModule: false);

ModuleExport exportsModule(String module) =>
    ModuleExport(key: module, name: module, isModule: true);

ModuleDeclaration module(
  String name, {
  List<String> imports = const [],
  List<ProviderDeclaration> providers = const [],
  List<ControllerDeclaration> controllers = const [],
  List<ModuleExport> exports = const [],
  bool global = false,
}) => ModuleDeclaration(
  header: ModuleHeader(
    key: name,
    name: name,
    importKeys: imports,
    origin: 'module $name',
  ),
  providers: providers,
  controllers: controllers,
  exports: exports,
  isGlobal: global,
);

/// Modules held in memory, recording the order the resolver reads them.
final class InMemoryModuleCatalog implements ModuleCatalog {
  InMemoryModuleCatalog(Iterable<ModuleDeclaration> modules)
    : _modules = {for (final module in modules) module.key: module};

  final Map<String, ModuleDeclaration> _modules;
  final headerReads = <String>[];
  final declarationReads = <String>[];

  @override
  ModuleHeader header(String moduleKey) {
    headerReads.add(moduleKey);
    return _modules[moduleKey]!.header;
  }

  @override
  ModuleDeclaration declaration(String moduleKey) {
    declarationReads.add(moduleKey);
    return _modules[moduleKey]!;
  }
}

/// Resolves [modules] from [root] with the default rules.
ResolvedDependencyGraph resolveGraph(
  String root,
  List<ModuleDeclaration> modules,
) => const ModuleDependencyResolver().resolve(
  root,
  InMemoryModuleCatalog(modules),
);

/// The scope of [moduleKey] in [graph].
ResolvedModuleScope scopeOf(ResolvedDependencyGraph graph, String moduleKey) =>
    graph.modules.singleWhere((scope) => scope.key == moduleKey);

/// `Type(dependency, ...)` for each provider, in construction order.
List<String> constructionsOf(ResolvedModuleScope scope) => [
  for (final construction in scope.providers)
    '${construction.declaration.token.name}('
        '${construction.arguments.map(_describe).join(', ')})',
];

/// `Type(dependency, ...)` for each controller.
List<String> controllerConstructionsOf(ResolvedModuleScope scope) => [
  for (final construction in scope.controllers)
    '${construction.declaration.token.name}('
        '${construction.arguments.map(_describe).join(', ')})',
];

String _describe(ResolvedArgument argument) {
  final instance = argument.instance;
  final value =
      '${instance.token.name}@${instance.moduleKey}'
      '${instance.kind == InstanceKind.external ? ' (external)' : ''}';
  return argument.parameter.kind.isNamed
      ? '${argument.parameter.name}: $value'
      : value;
}

String _lowerFirst(String value) =>
    '${value[0].toLowerCase()}${value.substring(1)}';

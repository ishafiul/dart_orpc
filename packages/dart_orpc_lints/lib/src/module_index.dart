import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/file_system.dart';

const _moduleAnnotation = 'Module';
const _moduleMarker = '@Module(';
const _dartExtension = '.dart';
const _pubspecFile = 'pubspec.yaml';
const _generatedSuffixes = ['.g.dart', '.orpc.dart', '.freezed.dart'];
const _importsArgument = 'imports';
const _providersArgument = 'providers';
const _bindingsArgument = 'bindings';
const _controllersArgument = 'controllers';
const _exportsArgument = 'exports';
const _globalArgument = 'global';

final class ModuleDeclaration {
  const ModuleDeclaration({
    required this.name,
    required this.imports,
    required this.providers,
    required this.controllers,
    required this.exports,
    required this.isGlobal,
  });

  final String name;
  final Set<String> imports;
  final Set<String> providers;
  final Set<String> controllers;
  final Set<String> exports;
  final bool isGlobal;

  bool owns(String typeName) =>
      providers.contains(typeName) || controllers.contains(typeName);
}

final class ModuleIndex {
  ModuleIndex(this._resources);

  final ResourceProvider _resources;
  final Map<String, ModuleDeclaration?> _ownerByPath = {};

  static final Expando<Map<String, _ParsedModules>> _parsedByProvider =
      Expando();

  Map<String, _ParsedModules> get _parsedByPath =>
      _parsedByProvider[_resources] ??= {};

  ModuleDeclaration? moduleOwning(String filePath) =>
      _ownerByPath.putIfAbsent(filePath, () => _findOwner(filePath));

  ModuleDeclaration? _findOwner(String filePath) {
    final file = _resources.getFile(filePath);
    final declaredHere = _modulesIn(file);
    if (declaredHere.isNotEmpty) {
      return declaredHere.length == 1 ? declaredHere.single : null;
    }
    var folder = file.parent;
    while (true) {
      final modules = [
        for (final candidate in _dartSourcesIn(folder))
          ..._modulesIn(candidate),
      ];
      if (modules.isNotEmpty) {
        return modules.length == 1 ? modules.single : null;
      }
      if (folder.isRoot || folder.getFile(_pubspecFile).exists) {
        return null;
      }
      folder = folder.parent;
    }
  }

  Iterable<File> _dartSourcesIn(Folder folder) =>
      folder.getChildren().whereType<File>().where(
        (file) =>
            file.shortName.endsWith(_dartExtension) &&
            !_generatedSuffixes.any(file.shortName.endsWith),
      );

  List<ModuleDeclaration> _modulesIn(File file) {
    if (!file.exists) {
      return const [];
    }
    final stamp = file.modificationStamp;
    final cached = _parsedByPath[file.path];
    if (cached != null && cached.stamp == stamp) {
      return cached.modules;
    }
    final modules = _parseModules(file.readAsStringSync(), file.path);
    _parsedByPath[file.path] = _ParsedModules(stamp, modules);
    return modules;
  }

  List<ModuleDeclaration> _parseModules(String content, String path) {
    if (!content.contains(_moduleMarker)) {
      return const [];
    }
    final unit = parseString(
      content: content,
      path: path,
      throwIfDiagnostics: false,
    ).unit;
    return [
      for (final declaration in unit.declarations.whereType<ClassDeclaration>())
        for (final annotation in declaration.metadata)
          if (_simpleName(annotation.name) == _moduleAnnotation)
            _moduleFrom(declaration.namePart.typeName.lexeme, annotation),
    ];
  }

  ModuleDeclaration _moduleFrom(String name, Annotation annotation) {
    final arguments = {
      for (final argument
          in annotation.arguments?.arguments.whereType<NamedArgument>() ??
              const <NamedArgument>[])
        argument.name.lexeme: argument.argumentExpression,
    };
    return ModuleDeclaration(
      name: name,
      imports: _typeNames(arguments[_importsArgument]),
      providers: {
        ..._typeNames(arguments[_providersArgument]),
        ..._typeNames(arguments[_bindingsArgument]),
      },
      controllers: _typeNames(arguments[_controllersArgument]),
      exports: _typeNames(arguments[_exportsArgument]),
      isGlobal: switch (arguments[_globalArgument]) {
        BooleanLiteral(:final value) => value,
        _ => false,
      },
    );
  }

  Set<String> _typeNames(Expression? expression) {
    if (expression is! ListLiteral) {
      return const {};
    }
    return {
      for (final element in expression.elements)
        if (element is Expression) ..._namesIn(element),
    };
  }

  Iterable<String> _namesIn(Expression expression) => switch (expression) {
    Identifier() => [_simpleName(expression)],
    MethodInvocation(:final argumentList) ||
    InstanceCreationExpression(:final argumentList) => [
      for (final argument in argumentList.arguments.whereType<NamedArgument>())
        ..._namesIn(argument.argumentExpression),
    ],
    _ => const [],
  };

  String _simpleName(Identifier identifier) => switch (identifier) {
    SimpleIdentifier(:final name) => name,
    PrefixedIdentifier(:final identifier) => identifier.name,
  };
}

final class _ParsedModules {
  const _ParsedModules(this.stamp, this.modules);

  final int stamp;
  final List<ModuleDeclaration> modules;
}

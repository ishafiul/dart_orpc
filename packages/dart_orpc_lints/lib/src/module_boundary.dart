import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:dart_orpc_lints/src/module_index.dart';
import 'package:dart_orpc_lints/src/orpc_elements.dart';

sealed class BoundaryCrossing {
  const BoundaryCrossing(this.typeName, this.owner);

  final String typeName;
  final ModuleDeclaration owner;
}

final class ForeignController extends BoundaryCrossing {
  const ForeignController(super.typeName, super.owner);
}

final class UnexportedProvider extends BoundaryCrossing {
  const UnexportedProvider(super.typeName, super.owner);
}

final class UndeclaredModuleDependency extends BoundaryCrossing {
  const UndeclaredModuleDependency(super.typeName, super.owner, this.consumer);

  final ModuleDeclaration consumer;
}

final class ModuleBoundary {
  ModuleBoundary(File currentFile)
    : _index = ModuleIndex(currentFile.provider),
      _currentPath = currentFile.path;

  static ModuleBoundary? of(RuleContext context) =>
      switch (context.currentUnit) {
        final unit? => ModuleBoundary(unit.file),
        null => null,
      };

  final ModuleIndex _index;
  final String _currentPath;

  ModuleDeclaration? get currentModule => _index.moduleOwning(_currentPath);

  BoundaryCrossing? crossingFor(Element? element) {
    if (element is! InterfaceElement) {
      return null;
    }
    final typeName = element.name;
    final consumer = currentModule;
    final declaringPath = declaringFilePath(element);
    if (typeName == null ||
        consumer == null ||
        declaringPath == null ||
        consumer.owns(typeName)) {
      return null;
    }
    final owner = _index.moduleOwning(declaringPath);
    if (owner == null || owner.name == consumer.name) {
      return null;
    }
    if (owner.controllers.contains(typeName)) {
      return ForeignController(typeName, owner);
    }
    if (!owner.providers.contains(typeName)) {
      return null;
    }
    if (!owner.exports.contains(typeName)) {
      return UnexportedProvider(typeName, owner);
    }
    if (owner.isGlobal || consumer.imports.contains(owner.name)) {
      return null;
    }
    return UndeclaredModuleDependency(typeName, owner, consumer);
  }

  bool isProvider(Element? element) {
    if (element is! InterfaceElement) {
      return false;
    }
    final typeName = element.name;
    final declaringPath = declaringFilePath(element);
    if (typeName == null) {
      return false;
    }
    final owners = [
      currentModule,
      if (declaringPath != null) _index.moduleOwning(declaringPath),
    ];
    return owners.any((module) => module?.owns(typeName) ?? false);
  }
}

part of '../rpc_module_generator.dart';

Future<String?> _generateModuleLibrary(
  LibraryReader library,
  BuildStep buildStep,
) async {
  final modules = library.classes
      .where((element) => _moduleChecker.hasAnnotationOfExact(element))
      .toList(growable: false);
  if (modules.isEmpty) {
    return null;
  }

  final sourceImportUri = _packageImportUriFor(buildStep.inputId);
  final imports = <String>{
    "import 'package:dart_orpc/dart_orpc.dart';",
    "import '$sourceImportUri';",
  };
  final exports = <String>{"export '$sourceImportUri';"};
  final moduleOutputs = <_GeneratedModuleOutput>[];

  for (final module in modules) {
    final annotation = _readModuleAnnotation(module);
    final moduleOutput = await _generateForModule(
      module,
      annotation: annotation,
      buildStep: buildStep,
    );
    moduleOutputs.add(moduleOutput);
    imports.addAll(moduleOutput.importDirectives);
  }

  final buffer = StringBuffer();
  for (final exportDirective in exports.toList()..sort()) {
    buffer.writeln(exportDirective);
  }
  buffer.writeln();
  for (final importDirective in imports.toList()..sort()) {
    buffer.writeln(importDirective);
  }
  for (final moduleOutput in moduleOutputs) {
    buffer
      ..writeln()
      ..writeln(moduleOutput.code);
  }

  return buffer.toString().trimRight();
}

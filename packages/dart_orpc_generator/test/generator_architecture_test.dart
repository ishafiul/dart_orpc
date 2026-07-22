import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  group('RpcModuleGenerator architecture', () {
    late Directory packageRoot;
    late Directory componentRoot;
    late File libraryFile;

    setUpAll(() async {
      final libraryUri = await Isolate.resolvePackageUri(
        Uri.parse('package:dart_orpc_generator/dart_orpc_generator.dart'),
      );
      if (libraryUri == null) {
        fail('Unable to resolve the dart_orpc_generator package root.');
      }

      packageRoot = File.fromUri(libraryUri).parent.parent;
      componentRoot = Directory(
        '${packageRoot.path}/lib/src/rpc_module_generator',
      );
      libraryFile = File(
        '${packageRoot.path}/lib/src/rpc_module_generator.dart',
      );
    });

    test('every component belongs to a documented architectural layer', () {
      const layers = {'analysis', 'emission', 'model', 'pipeline', 'support'};
      final unexpected = <String>[];

      for (final entity in componentRoot.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final relativePath = _relativePath(entity, componentRoot);
        if (!layers.contains(relativePath.split('/').first)) {
          unexpected.add(relativePath);
        }
      }

      expect(unexpected, isEmpty);
    });

    test('every component is registered as a library part', () {
      final source = libraryFile.readAsStringSync();
      final declaredParts = RegExp(
        "part 'rpc_module_generator/([^']+)';",
      ).allMatches(source).map((match) => match.group(1)!).toSet();
      final actualParts = componentRoot
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => _relativePath(file, componentRoot))
          .toSet();

      expect(declaredParts, actualParts);
    });

    test('emitters do not depend on analyzer API types', () {
      const analyzerTypes = {
        'BuildStep',
        'ConstantReader',
        'DartObject',
        'DartType',
        'Element',
        'InterfaceElement',
        'LibraryReader',
        'TypeChecker',
      };
      final violations = <String>[];
      final emissionRoot = Directory('${componentRoot.path}/emission');

      for (final file
          in emissionRoot
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        for (final type in analyzerTypes) {
          if (RegExp('\\b$type\\b').hasMatch(source)) {
            violations.add('${_relativePath(file, componentRoot)}: $type');
          }
        }
      }

      expect(violations, isEmpty);
    });
  });
}

String _relativePath(File file, Directory root) {
  final prefix = '${root.path}${Platform.pathSeparator}';
  return file.path
      .substring(prefix.length)
      .replaceAll(Platform.pathSeparator, '/');
}

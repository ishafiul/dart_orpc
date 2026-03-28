import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:luthor/luthor.dart';
import 'package:source_gen/source_gen.dart';

const _luthorFieldRefChecker = TypeChecker.typeNamed(
  Luthor,
  inPackage: 'luthor',
);

final class RpcDtoFieldRefGenerator extends Generator {
  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final buffer = StringBuffer();
    var wroteAny = false;

    for (final element in library.classes) {
      if (!_shouldGenerateFieldRefs(element)) {
        continue;
      }

      final fieldNames = _resolveFieldNames(element);
      if (fieldNames.isEmpty) {
        continue;
      }

      wroteAny = true;
      buffer..writeln('abstract final class ${element.displayName}Fields {');
      for (final fieldName in fieldNames) {
        buffer.writeln(
          "  static const $fieldName = RpcInputField<${element.displayName}>('$fieldName');",
        );
      }
      buffer
        ..writeln('}')
        ..writeln();
    }

    if (!wroteAny) {
      return '';
    }

    return buffer.toString();
  }

  bool _shouldGenerateFieldRefs(InterfaceElement element) {
    if (element.isPrivate || element.displayName.endsWith('Fields')) {
      return false;
    }

    if (_luthorFieldRefChecker.hasAnnotationOfExact(element)) {
      return true;
    }

    final hasFromJsonFactory = element.constructors.any((constructor) {
      final name = constructor.name ?? '';
      return constructor.isFactory && name == 'fromJson';
    });
    final hasToJson = element.methods.any(
      (method) => !method.isStatic && method.displayName == 'toJson',
    );

    return hasFromJsonFactory && hasToJson;
  }

  List<String> _resolveFieldNames(InterfaceElement element) {
    final fieldNames = <String>{};

    for (final field in element.fields) {
      final name = field.displayName;
      if (field.isStatic || name.startsWith('_')) {
        continue;
      }
      fieldNames.add(name);
    }

    for (final getter in element.getters) {
      final name = getter.displayName;
      if (getter.isStatic ||
          name.startsWith('_') ||
          name == 'hashCode' ||
          name == 'runtimeType') {
        continue;
      }
      fieldNames.add(name);
    }

    if (fieldNames.isEmpty) {
      final candidateConstructors = element.constructors.where((constructor) {
        final name = constructor.name ?? '';
        return name.isEmpty || name == 'new';
      });

      for (final constructor in candidateConstructors) {
        for (final parameter in constructor.formalParameters) {
          final name = parameter.displayName;
          if (name.startsWith('_')) {
            continue;
          }
          fieldNames.add(name);
        }
      }
    }

    return fieldNames.toList(growable: false)..sort();
  }
}

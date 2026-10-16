import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:luthor/luthor.dart';
import 'package:source_gen/source_gen.dart';

import 'analysis/dto_field_discovery.dart';

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
    final fieldNames = {
      for (final member in discoverDtoMembers(element)) member.name,
    };
    if (fieldNames.isEmpty) {
      fieldNames.addAll(
        discoverDtoConstructorParameters(element).map((field) => field.name),
      );
    }

    return fieldNames.toList(growable: false)..sort();
  }
}

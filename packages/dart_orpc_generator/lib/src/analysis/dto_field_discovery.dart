import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// One field declaration, getter, or constructor parameter before merging.
///
/// Keep its source element so callers can interpret annotations and diagnose
/// conflicting declarations without losing their original location.
final class DtoFieldCandidate {
  const DtoFieldCandidate({required this.element, required this.type});

  final Element element;
  final DartType type;

  String get name => element.displayName;
}

/// Public instance members, with fields before getters in declaration order.
///
/// Synthetic getters remain candidates: binding analysis must see annotations
/// on every declaration, while field-reference generation deduplicates names.
Iterable<DtoFieldCandidate> discoverDtoMembers(InterfaceElement element) sync* {
  for (final field in element.fields) {
    if (!field.isStatic && !field.displayName.startsWith('_')) {
      yield DtoFieldCandidate(element: field, type: field.type);
    }
  }
  for (final getter in element.getters) {
    final name = getter.displayName;
    if (!getter.isStatic &&
        !name.startsWith('_') &&
        name != 'hashCode' &&
        name != 'runtimeType') {
      yield DtoFieldCandidate(element: getter, type: getter.returnType);
    }
  }
}

/// Public parameters of unnamed constructors, including unnamed factories.
///
/// Consumers decide whether these supplement members or are a fallback when
/// no members exist. Named constructors, such as fromJson, do not contribute.
Iterable<DtoFieldCandidate> discoverDtoConstructorParameters(
  InterfaceElement element,
) sync* {
  for (final constructor in element.constructors) {
    final name = constructor.name ?? '';
    if (name.isNotEmpty && name != 'new') continue;
    for (final parameter in constructor.formalParameters) {
      if (!parameter.displayName.startsWith('_')) {
        yield DtoFieldCandidate(element: parameter, type: parameter.type);
      }
    }
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

const _annotationsLibraryPrefix = 'package:dart_orpc_annotations/';
const _coreLibraryPrefix = 'package:dart_orpc_core/';
const _controllerAnnotation = 'Controller';
const _serviceAnnotation = 'Service';
const _repositoryAnnotation = 'Repository';
const _guardInterface = 'RpcGuard';
const _rpcExceptionClass = 'RpcException';
const _errorClass = 'Error';
const _ioLibraries = {'dart:io', 'dart:_http'};

bool isDeclaredUnder(Element? element, String libraryPrefix) =>
    element?.library?.uri.toString().startsWith(libraryPrefix) ?? false;

bool isIoElement(Element? element) =>
    _ioLibraries.contains(element?.library?.uri.toString());

String? declaringFilePath(Element element) =>
    element.firstFragment.libraryFragment?.source.fullName;

extension OrpcClassDeclaration on ClassDeclaration {
  bool get isOrpcController => metadata.any(_isControllerAnnotation);

  String get className => namePart.typeName.lexeme;
}

bool _isControllerAnnotation(Annotation annotation) {
  final element = annotation.element;
  return element is ConstructorElement &&
      element.enclosingElement.name == _controllerAnnotation &&
      isDeclaredUnder(element, _annotationsLibraryPrefix);
}

extension OrpcErrorTypes on DartType {
  bool get isRpcException => _selfAndSupertypes.any(
    (type) =>
        type.element.name == _rpcExceptionClass &&
        isDeclaredUnder(type.element, _coreLibraryPrefix),
  );

  bool get isDartCoreError => _selfAndSupertypes.any(
    (type) =>
        type.element.name == _errorClass && (type.element.library.isDartCore),
  );

  Iterable<InterfaceType> get _selfAndSupertypes {
    final self = this;
    if (self is! InterfaceType) {
      return const [];
    }
    return [self, ...self.allSupertypes];
  }
}

/// The architectural role of a class, from its dart_orpc annotation, or
/// [guard] for an `RpcGuard` implementation.
enum ProviderRole {
  controller('controller'),
  service('service'),
  repository('repository'),
  guard('guard');

  const ProviderRole(this.label);

  final String label;
}

ProviderRole? roleOf(Element? element) {
  if (element is! InterfaceElement) {
    return null;
  }
  for (final annotation in element.metadata.annotations) {
    final constructor = annotation.element;
    if (constructor is! ConstructorElement ||
        !isDeclaredUnder(constructor, _annotationsLibraryPrefix)) {
      continue;
    }
    switch (constructor.enclosingElement.name) {
      case _controllerAnnotation:
        return ProviderRole.controller;
      case _serviceAnnotation:
        return ProviderRole.service;
      case _repositoryAnnotation:
        return ProviderRole.repository;
    }
  }
  final implementsGuard = element.allSupertypes.any(
    (type) =>
        type.element.name == _guardInterface &&
        isDeclaredUnder(type.element, _coreLibraryPrefix),
  );
  return implementsGuard ? ProviderRole.guard : null;
}

/// Whether [role] may depend on a class with role [dependency].
bool mayDependOn(ProviderRole role, ProviderRole dependency) =>
    switch ((role, dependency)) {
      (ProviderRole.controller, ProviderRole.service) => true,
      (ProviderRole.service, ProviderRole.service) => true,
      (ProviderRole.service, ProviderRole.repository) => true,
      (ProviderRole.guard, ProviderRole.service) => true,
      (_, ProviderRole.guard) => true,
      _ => false,
    };

part of '../rpc_module_generator.dart';

enum _InvocationParameterSourceKind {
  context,
  rpcInput,
  path,
  query,
  header,
  body,
}

final class _ResolvedInvocationParameter {
  const _ResolvedInvocationParameter({
    required this.parameterName,
    required this.source,
    required this.typeCode,
    required this.wireName,
    required this.typeName,
    required this.typeElement,
    required this.usesLuthor,
  });

  final String parameterName;
  final _InvocationParameterSourceKind source;
  final String typeCode;
  final String? wireName;
  final String? typeName;
  final Element? typeElement;
  final bool usesLuthor;
}

final class _ResolvedPathMapping {
  const _ResolvedPathMapping({required this.method, required this.path});

  final String method;
  final String path;
}

final class _ResolvedOpenApiSchemaComponent {
  const _ResolvedOpenApiSchemaComponent({
    required this.name,
    required this.validatorExpression,
  });

  final String name;
  final String validatorExpression;
}

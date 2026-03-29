part of '../rpc_module_generator.dart';

final class _ControllerBinding {
  const _ControllerBinding({
    required this.typeName,
    required this.instanceName,
    required this.instantiationCode,
    required this.controllerElement,
    required this.clientClassName,
    required this.clientGetterName,
    required this.procedures,
  });

  final String typeName;
  final String instanceName;
  final String instantiationCode;
  final InterfaceElement controllerElement;
  final String clientClassName;
  final String clientGetterName;
  final List<_ResolvedProcedure> procedures;

  List<_ResolvedProcedure> get rpcCompatibleProcedures => procedures
      .where((procedure) => procedure.supportsRpcGeneration)
      .toList(growable: false);
}

final class _ResolvedGuardBinding {
  const _ResolvedGuardBinding({
    required this.typeKey,
    required this.typeName,
    required this.variableName,
  });

  final String typeKey;
  final String typeName;
  final String variableName;
}

final class _ResolvedCustomMetadata {
  const _ResolvedCustomMetadata({required this.key, required this.value});

  final String key;
  final JsonObject value;
}

final class _GeneratedContainerMember {
  const _GeneratedContainerMember({required this.typeName, required this.name});

  final String typeName;
  final String name;
}

final class _ComposedRpcClientGetter {
  const _ComposedRpcClientGetter({
    required this.clientClassName,
    required this.clientGetterName,
    required this.initializerExpression,
  });

  final String clientClassName;
  final String clientGetterName;
  final String initializerExpression;
}

final class _ResolvedProcedure {
  const _ResolvedProcedure({
    required this.controllerNamespace,
    required this.methodName,
    required this.rpcMethod,
    required this.guardBindings,
    required this.customMetadata,
    required this.parameters,
    required this.restInvocationParameters,
    this.restRpcInput,
    required this.hasInput,
    this.path,
    this.inputTypeCode,
    this.inputTypeName,
    this.inputTypeElement,
    this.inputParameterName,
    this.description,
    this.tags = const [],
    required this.inputUsesLuthor,
    required this.outputTypeCode,
    required this.outputTypeName,
    required this.outputTypeElement,
    required this.outputUsesLuthor,
    required this.supportsRpcGeneration,
    required this.serverInvocationArguments,
  });

  final String controllerNamespace;
  final String methodName;
  final String rpcMethod;
  final List<_ResolvedGuardBinding> guardBindings;
  final List<_ResolvedCustomMetadata> customMetadata;
  final _ResolvedPathMapping? path;
  final List<_ResolvedParameter> parameters;
  final List<_ResolvedInvocationParameter> restInvocationParameters;
  final _ResolvedRestRpcInput? restRpcInput;
  final bool hasInput;
  final String? inputTypeCode;
  final String? inputTypeName;
  final Element? inputTypeElement;
  final String? inputParameterName;
  final String? description;
  final List<String> tags;
  final bool inputUsesLuthor;
  final String outputTypeCode;
  final String outputTypeName;
  final Element? outputTypeElement;
  final bool outputUsesLuthor;
  final bool supportsRpcGeneration;
  final String serverInvocationArguments;

  List<String> get guardTypeNames => [
    for (final guardBinding in guardBindings) guardBinding.typeName,
  ];
}

final class _ResolvedParameter {
  const _ResolvedParameter({
    required this.parameterName,
    required this.wireName,
    required this.source,
    required this.typeCode,
  });

  final String parameterName;
  final String wireName;
  final ProcedureParameterSourceKind source;
  final String typeCode;
}

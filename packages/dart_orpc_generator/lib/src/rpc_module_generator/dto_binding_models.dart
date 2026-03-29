part of '../rpc_module_generator.dart';

final class _ResolvedDtoField {
  const _ResolvedDtoField({
    required this.name,
    required this.typeCode,
    this.defaultSource,
    this.defaultWireName,
  });

  final String name;
  final String typeCode;
  final String? defaultSource;
  final String? defaultWireName;
}

final class _ResolvedDtoFieldBinding {
  const _ResolvedDtoFieldBinding({required this.source, this.wireName});

  final String source;
  final String? wireName;
}

final class _ResolvedDtoFieldBuilder {
  _ResolvedDtoFieldBuilder({required this.name, required this.typeCode});

  final String name;
  final String typeCode;
  String? defaultSource;
  String? defaultWireName;

  void applyBinding(
    _ResolvedDtoFieldBinding binding, {
    required String methodName,
    required Element element,
  }) {
    final nextWireName = binding.wireName ?? name;
    if (defaultSource != null) {
      if (defaultSource != binding.source || defaultWireName != nextWireName) {
        throw InvalidGenerationSourceError(
          'REST-enabled RPC method "$methodName" found conflicting source annotations for DTO field "$name".',
          element: element,
        );
      }
      return;
    }
    defaultSource = binding.source;
    defaultWireName = nextWireName;
  }

  _ResolvedDtoField build() {
    return _ResolvedDtoField(
      name: name,
      typeCode: typeCode,
      defaultSource: defaultSource,
      defaultWireName: defaultWireName,
    );
  }
}

final class _ResolvedRestInputField {
  const _ResolvedRestInputField({
    required this.name,
    required this.typeCode,
    required this.wireName,
  });

  final String name;
  final String typeCode;
  final String wireName;
}

final class _ResolvedRpcInputField {
  const _ResolvedRpcInputField({
    required this.fieldName,
    required this.wireName,
    required this.source,
  });

  final String fieldName;
  final String wireName;
  final String source;
}

final class _ResolvedRpcInputDetails {
  const _ResolvedRpcInputDetails({
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final List<_ResolvedRpcInputField> path;
  final List<_ResolvedRpcInputField> query;
  final List<_ResolvedRpcInputField> headers;
  final List<_ResolvedRpcInputField> body;
}

enum _ResolvedRestRpcInputMode { query, body }

final class _ResolvedRestRpcInput {
  const _ResolvedRestRpcInput({
    required this.parameterName,
    required this.mode,
    required this.pathFields,
    required this.queryFields,
    required this.headerFields,
    required this.bodyFields,
    required this.metadataParameters,
  });

  final String parameterName;
  final _ResolvedRestRpcInputMode mode;
  final List<_ResolvedRestInputField> pathFields;
  final List<_ResolvedRestInputField> queryFields;
  final List<_ResolvedRestInputField> headerFields;
  final List<_ResolvedRestInputField> bodyFields;
  final List<_ResolvedParameter> metadataParameters;
}
